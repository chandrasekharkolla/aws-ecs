variable "vpc_name" {
  type    = string
  default = ""
}

variable "vpc_cidr" {
  type    = string
  default = ""
}

variable "tags" {
  description = "Tags for AWS resources"
  type        = any
  default     = ""
}

variable "region" {
  type    = string
  default = ""
}