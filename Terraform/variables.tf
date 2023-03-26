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


##################### EC2 Control plane #####################
variable "cp_template" {
  type = object({
    ami           = string
    instance_type = string
    key_name      = string
  })

  default = {
    ami           = "ami-09cd747c78a9add63"
    instance_type = "t2.micro"
    key_name      = "cp-key"
  }
}

variable "cp_names" {
  type        = set(string)
  description = "list of dinstinct control plane instance name"
  default     = ["cp-plane-1"]
}

variable "cp_tags" {
  type    = map(string)
  default = {}
}

##################### EC2 node #####################

variable "node_template" {
  type = object({
    ami           = string
    instance_type = string
    key_name      = string
  })

  default = {
    ami           = "ami-09cd747c78a9add63"
    instance_type = "t3.micro"
    key_name      = "node-key"
  }
}

variable "node_names" {
  type        = set(string)
  description = "list of dinstinct control plane instance name"
  default     = ["node-1"]
}

variable "node_tags" {
  type    = map(string)
  default = {}
}

variable "node_public" {
  type        = bool
  description = "if nodes to be accessible to the public"
  default     = false
}