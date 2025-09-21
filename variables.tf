variable "region" {
  default = "us-eaast-1"
}

variable "access_key" {
  type = string
}

variable "secret_key" {
  type = string
}

variable "asg_name" {
  description = "ASG name"
  type        = string
}

variable "environment" {
  description = "Environment name like prod, dev"
  type        = string
}

variable "desired_capacity" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 2
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_instance_lifetime_days" {
  type    = number
  default = 30
}

variable "instance_warmup_seconds" {
  type    = number
  default = 300
}
