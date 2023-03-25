variable "environment" {
  type = string
}

################### VPC ####################
variable "vpc_create" {
  type    = bool
  default = false
}

variable "vpc_name" {
  type    = string
  default = ""
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azs" {
  type = list(string)
}

variable "private_subnets" {
  type    = list(string)
  default = []
}

variable "public_subnets" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
