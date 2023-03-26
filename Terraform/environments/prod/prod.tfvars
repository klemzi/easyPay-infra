environment = "prod"

################ vpc #####################
vpc_create = true
vpc_name   = "easypay-vpc"
vpc_cidr   = "10.0.0.0/16"

azs             = ["us-east-1a", "us-east-1b"]
private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

tags = {
  Org = "EasyPay"
}

################ Control plane ###############

cp_template = {
  ami           = "ami-0557a15b87f6559cf"
  instance_type = "t2.micro"
  key_name      = "easypay-key"
}
# one control plane
cp_names = ["cp-1"]

################## nodes #####################

node_template = {
  ami           = "ami-0557a15b87f6559cf"
  instance_type = "t3.micro"
  key_name      = "easypay-key"
}
# 2 nodes
node_names = ["node-1", "node-2"]

