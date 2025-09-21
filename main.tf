module "asg" {
  source       = "./modules/nginxserver"
  asg_name     = "asx-app-server"
  environment  = "prod"
  region       = var.region
}
