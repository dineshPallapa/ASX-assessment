output "load_balancer_url" {
  value = "http://${module.asg.alb_dns}"
}

# output "rendered_user_data" {
#   value = templatefile("${path.module}/modules/nginxserver/user_data.sh.tpl", { environment = var.environment })
# }
