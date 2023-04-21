environment = "prod"

################ vpc #####################
vpc_create = true
vpc_name   = "easypay-vpc"
vpc_cidr   = "10.0.0.0/16"

tags = {
  Org = "EasyPay"
}

################ Control plane ###############

cp_template = {
  ami           = "ami-0aa2b7722dc1b5612"
  instance_type = "t3.small"
  key_name      = "easypay-key"
}
# one control plane
cp_names = ["cp-1"]

################## nodes #####################

node_template = {
  ami           = "ami-0aa2b7722dc1b5612"
  instance_type = "t3.micro"
  key_name      = "easypay-key"
}
# 2 nodes
node_names = ["node-1", "node-2"]

