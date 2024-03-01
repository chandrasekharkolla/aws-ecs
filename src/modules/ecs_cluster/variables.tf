variable "cluster_name" {
  type    = string
  default = ""
}

variable "cloudwatch_group_name" {
  type    = string
  default = ""
}

variable "service_name" {
  type    = string
  default = ""
}

variable "task_definition_name" {
  type    = string
  default = ""
}

variable "lb_target_group_name" {
  type    = string
  default = ""
}

variable "vpc_id" {
  type    = string
  default = ""
}

variable "public_subnets" {
  type    = list(string)
  default = ["", ""]
}

variable "private_subnets" {
  type    = list(string)
  default = ["", ""]
}

variable "taskRoleArn" {
  type    = string
  default = null
}

variable "ecs_executionRoleArn" {
  type    = string
  default = null
}

variable "task_cpu" {
  type    = number
  default = null
}

variable "task_memory" {
  type    = number
  default = null
}

variable "ecs_task_tags" {
  type    = any
  default = null
}

variable "lb_name" {
  type    = string
  default = ""
}

variable "access_log_bucket_name" {
  type    = string
  default = ""
}

variable "image_uri" {
  type    = string
  default = ""
}

variable "hosted_zone_name" {
  type    = string
  default = ""
}

variable "cert_domain_names" {
  type    = list(string)
  default = [""]
}

variable "subject_alternative_names" {
  type    = list(string)
  default = [""]
}

variable "cert_domain_name" {
  type    = string
  default = ""
}
