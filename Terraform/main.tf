locals {
  # ref --> https://kubernetes.io/docs/reference/networking/ports-and-protocols/
  cp_rules        = csvdecode(file("./configs/rules/cp.csv"))
  node_rules      = csvdecode(file("./configs/rules/node.csv"))
  cluster_ssh_key = base64decode(file("./configs/pb-key/easypay"))
  baston_ssh_key  = base64decode(file("./configs/pb-key/baston"))
  anywhere_ipv4   = "0.0.0.0/0"
  anywhere_ipv6   = "::/0"
  azs             = slice(data.aws_availability_zones.azs.names, 0, 2)
}

# get availability zones
data "aws_availability_zones" "azs" {
  state = "available"
}

# vpc module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 100)]

  enable_nat_gateway = true # private subnet access to the internet
  single_nat_gateway = true # we just need one shared NAT for now

  enable_dns_hostnames = true

  tags = merge({
    Terraform   = "true"
    Environment = var.environment
  }, var.tags)
}

# ssh key pair
resource "aws_key_pair" "ssh_key" {
  key_name   = var.cp_template.key_name
  public_key = local.cluster_ssh_key
}

resource "aws_key_pair" "baston_ssh_key" {
  key_name   = "baston-key"
  public_key = local.baston_ssh_key
}

# ec2 module
module "ec2-cp" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "4.3.0"

  for_each = toset(var.cp_names)

  name = "instance-${each.key}"

  ami                    = var.cp_template.ami
  instance_type          = var.cp_template.instance_type
  key_name               = aws_key_pair.ssh_key.key_name
  monitoring             = true
  vpc_security_group_ids = [aws_security_group.cp_sg.id]
  subnet_id              = module.vpc.public_subnets[index(tolist(var.cp_names), each.value) % length(module.vpc.public_subnets)]

  tags = merge({
    Terraform   = "true"
    instance    = "control-plane"
    Environment = var.environment
  }, var.tags)
}


# ec2 module
module "ec2-nodes" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "4.3.0"

  for_each = toset(var.node_names)

  name = "instance-${each.key}"

  ami                    = var.node_template.ami
  instance_type          = var.node_template.instance_type
  key_name               = aws_key_pair.ssh_key.key_name
  monitoring             = true
  vpc_security_group_ids = [aws_security_group.node_sg.id]
  subnet_id              = var.node_public ? module.vpc.public_subnets[index(tolist(var.node_names), each.value) % length(module.vpc.public_subnets)] : module.vpc.private_subnets[index(tolist(var.node_names), each.value) % length(module.vpc.private_subnets)]

  tags = merge({
    Terraform   = "true"
    instance    = "node"
    Environment = var.environment
  }, var.tags)
}

# ec2 module
module "baston-server" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "4.3.0"

  name = "baston"

  ami                    = "ami-0557a15b87f6559cf"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.baston_ssh_key.key_name
  monitoring             = true
  vpc_security_group_ids = [aws_security_group.baston_ssh_allow.id]
  subnet_id              = module.vpc.public_subnets[0] # stay in just one public subnet for now

  tags = {
    Terraform   = "true"
    Environment = var.environment
    instance    = "baston"
  }
}

resource "aws_security_group" "cp_sg" {
  name        = "allow_cp_ports"
  description = "allow control plane inbound traffic"
  vpc_id      = module.vpc.vpc_id

  dynamic "ingress" {
    for_each = local.cp_rules
    content {
      description     = ingress.value.description
      from_port       = ingress.value.start
      to_port         = ingress.value.end
      protocol        = "tcp"
      security_groups = [aws_security_group.node_sg.id, aws_security_group.cp_http_allow.id]
    }
  }

  ingress {
    description     = "allow ssh from baston"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.baston_ssh_allow.id]
  }

  ingress {
    description     = "allow ping from baston"
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.baston_ssh_allow.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [local.anywhere_ipv4]
  }

  tags = {
    Name = "allow_cp_ports"
  }
}

resource "aws_security_group" "cp_http_allow" {
  name        = "lb-allow-http"
  description = "allow http to lb"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "allow http to lb"
    cidr_blocks = [local.anywhere_ipv4]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }

  egress {
    cidr_blocks = [local.anywhere_ipv4]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }

  tags = {
    Name = "lb Public"
  }
}

resource "aws_security_group" "baston_ssh_allow" {
  name        = "baston-allow-ssh"
  description = "allow ssh to baston"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "allow ssh to baston"
    cidr_blocks = [local.anywhere_ipv4]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }

  egress {
    cidr_blocks = [local.anywhere_ipv4]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }

  tags = {
    Name = "baston ssh allow"
  }
}

resource "aws_security_group" "node_sg" {
  name        = "allow_node_ports"
  description = "allow control plane inbound traffic"
  vpc_id      = module.vpc.vpc_id

  dynamic "ingress" {
    for_each = local.node_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.start
      to_port     = ingress.value.end
      protocol    = "tcp"
      cidr_blocks = var.node_public ? [local.anywhere_ipv4] : [var.vpc_cidr]
    }
  }

  ingress {
    description     = "allow ssh from baston"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.baston_ssh_allow.id]
  }

  ingress {
    description     = "allow ping from baston"
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.baston_ssh_allow.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [local.anywhere_ipv4]
  }

  tags = {
    Name = "allow_node_ports"
  }
}

# module "easypay-lb" {
#   source  = "terraform-aws-modules/alb/aws"
#   version = "8.6.0"

#   name = "easypay-alb"

#   load_balancer_type = "application"

#   vpc_id  = module.vpc.vpc_id
#   subnets = [module.vpc.public_subnets[0], module.vpc.public_subnets[1]]

#   target_groups = [
#     {
#       name_prefix      = "pref-"
#       backend_protocol = "TCP"
#       backend_port     = 6443
#       target_type      = "instance"
#     }
#   ]

#   https_listeners = [
#     {
#       port               = 443
#       protocol           = "TLS"
#       certificate_arn    = "arn:aws:iam::123456789012:server-certificate/test_cert-123456789012"
#       target_group_index = 0
#       target_groups = {

#       }
#     }
#   ]

#   http_tcp_listeners = [
#     {
#       port               = 80
#       protocol           = "TCP"
#       target_group_index = 0
#     }
#   ]

#   tags = {
#     Environment = "Test"
#   }
# }