locals {
  common_tags = {
    Environment = var.environment
    Project     = var.asg_name
    ManagedBy   = "ASX"
  }
}

# data "aws_ami" "amazon_linux" {
#   most_recent = true
#   filter {
#     name   = "name"
#     values = ["amzn2-ami-hvm-*-x86_64-gp2"]
#   }
#   owners = ["amazon"]
# }

data "aws_ami" "amazon_linux2" {
  most_recent = true
  owners      = ["amazon"]

  # filter best-effort to Amazon Linux 2023 patterns
  filter {
    name   = "name"
    values = ["amzn-ami-2023-*", "amzn-2023-*", "al2023-ami-*", "amzn-2023-*-x86_64*"]
  }
}

# Create VPC, Internet Gateway, Subnets, Route Tables, and Security Groups
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.environment}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.environment}-igw"
  }
}

#create NAT Gateway and EIP for private subnet outbound internet access
resource "aws_eip" "nat_eip" {
  tags = {
    Name = "${var.environment}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(aws_subnet.public.*.id, 0)  # Choose one public subnet for NAT gateway

  tags = {
    Name = "${var.environment}-nat-gateway"
  }
}


#create public and private subnets, route tables, and associations
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.environment}-public-rt"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(["10.0.101.0/24", "10.0.102.0/24"], count.index)
  availability_zone       = element(["us-east-1a", "us-east-1b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment}-public-subnet-${count.index}"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(["10.0.1.0/24", "10.0.2.0/24"], count.index)
  availability_zone = element(["us-east-1a", "us-east-1b"], count.index)
  tags = {
    Name = "${var.environment}-private-subnet-${count.index}"
  }
}

#
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-private-rt"
  }
}

resource "aws_route" "private_internet_access" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
}

resource "aws_route_table_association" "private_subnet_association" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}


#
resource "aws_security_group" "alb_sg" {
  name        = "${var.environment}-alb-sg"
  description = "Allow HTTP(S) from internet to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "asg" {
  name        = "${var.environment}-asg-sg"
  description = "Allow HTTP inbound from ALB"
  vpc_id      = aws_vpc.main.id

  # Allow traffic from ALB SG on port 80
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "Allow ALB instance on 80"
  }

  # Keep egress open for SSM -> endpoints and other outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# CREATE ROELE, POLICY ATTACHMENTS, INSTANCE PROFILE FOR SSM
resource "aws_iam_role" "ssm_role" {
  name = "${var.environment}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_policy_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "${var.environment}-ssm-instance-profile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_launch_template" "asg_lt" {
  name_prefix   = "${var.asg_name}-lt-"
  image_id      = data.aws_ami.amazon_linux2.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ssm_instance_profile.name
  }

  monitoring {
    enabled = true
  }

  vpc_security_group_ids = [aws_security_group.asg.id]

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", { environment = var.environment }))

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "app_alb" {
  name               = "${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id
}


resource "aws_lb_target_group" "tg" {
  name     = "${var.environment}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_autoscaling_group" "asg" {
  name                      = "${var.environment}-${var.asg_name}-asg"
  desired_capacity          = var.desired_capacity
  max_size                  = var.max_size
  min_size                  = var.min_size
  vpc_zone_identifier       = aws_subnet.private[*].id
  target_group_arns         = [aws_lb_target_group.tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300
  protect_from_scale_in     = false
  max_instance_lifetime     = var.max_instance_lifetime_days * 24 * 60 * 60
  default_instance_warmup   = var.instance_warmup_seconds

  launch_template {
    id      = aws_launch_template.asg_lt.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage        = 50
      max_healthy_percentage        = 200
      instance_warmup               = var.instance_warmup_seconds
      scale_in_protected_instances  = "Ignore"
      standby_instances             = "Ignore"
      skip_matching                 = false
      checkpoint_percentages        = [50]
      checkpoint_delay              = 300  # 5 minutes as integer seconds
    }

    triggers = ["tag", "desired_capacity"]
  }

  instance_maintenance_policy {
    min_healthy_percentage = 100
    max_healthy_percentage = 110
  }

  termination_policies = ["OldestInstance", "Default"]

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-${var.asg_name}-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }

  depends_on = [
    aws_lb_target_group.tg,
    aws_cloudwatch_log_group.var_log_messages
  ]
}

resource "aws_cloudwatch_log_group" "var_log_messages" {
  name              = "/var/log/privat/messages"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_stream" "var_log_stream" {
  name           = "var-log-messages-stream"
  log_group_name = aws_cloudwatch_log_group.var_log_messages.name
}
