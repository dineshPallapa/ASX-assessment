The core of ASX infrastucture cloud automation is based on terraform.
Create a Terraform module with the following requiments for AWS Autoscaling group to run ephemeral EC2 instances:
The modules input should be:
1) Autoscaling group name
2) Load balancer URL

Module requirements:
1) It should run the lastest version of Amazon Linux 2023 every time is launched
2) The EC2 instance should be accssible via SSM Session Manager
3) The EC2 instance /var/log/messages should be available on Cloud Watch Log
4) The auto scalling group should replace the instance every 30 days
5) Nginx must be installed and listening to port 80
6) The EC2 intances must be hosted on private subnets

Bonus:
7) Create an application load balancer that listen TLS over HTTP and reaches the EC2 instances above on NGINX
