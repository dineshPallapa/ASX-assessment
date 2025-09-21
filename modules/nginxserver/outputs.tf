output "asg_name" {
  value = var.asg_name
}

output "alb_dns" {
  value = aws_lb.app_alb.dns_name
}

output "load_balancer_url" {
  value = "http://${aws_lb.app_alb.dns_name}"
}

# output "rendered_user_data" {
#   value = templatefile("${path.module}/user_data.sh.tpl", { environment = var.environment })
# }