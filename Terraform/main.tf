locals {
  # ref --> https://kubernetes.io/docs/reference/networking/ports-and-protocols/
  cp_rules      = csvdecode(file("./csv-configs/rules/cp.csv"))
  node_rules    = csvdecode(file("./csv-configs/rules/node.csv"))
  anywhere_ipv4 = "0.0.0.0/0"
  anywhere_ipv6 = "::/0"
}

# vpc module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  tags = merge({
    Terraform   = "true"
    Environment = var.environment
  }, var.tags)
}

# ec2 module
module "ec2-cp" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "4.3.0"

  for_each = toset(var.cp_names)

  name = "instance-${each.key}"

  ami                    = var.cp_template.ami
  instance_type          = var.cp_template.instance_type
  key_name               = var.cp_template.key_name
  monitoring             = true
  vpc_security_group_ids = []
  subnet_id              = module.vpc.public_subnets[index(tolist(var.cp_names), each.value) % length(module.vpc.public_subnets)]

  tags = merge({
    Terraform   = "true"
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
  key_name               = var.node_template.key_name
  monitoring             = true
  vpc_security_group_ids = [aws_security_group.node_sg.id]
  subnet_id              = var.node_public ? module.vpc.public_subnets[index(tolist(var.node_names), each.value) % length(module.vpc.public_subnets)] : module.vpc.private_subnets[index(tolist(var.node_names), each.value) % length(module.vpc.private_subnets)]

  tags = merge({
    Terraform   = "true"
    Environment = var.environment
  }, var.tags)
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

  ingress {
    description = "allow http to lb"
    cidr_blocks = [local.anywhere_ipv4]
    from_port   = 80
    to_port     = 80
    protocol    = "-1"
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