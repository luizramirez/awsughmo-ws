module "bucket" {
  source      = "./modules/s3_bucket"
  bucket_name = var.bucket_name
  tags        = local.common_tags
}

module "ec2-instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  subnet_id   = data.aws_subnet.default_public.id

  version = "6.1.1"
}

module "web" {
  source             = "./modules/ec2_instance"
  instance_type      = var.instance_type
  vpc_id             = data.aws_vpc.default.id
  public_subnet_id   = data.aws_subnet.default_public.id
  allow_http_ingress = true
  tags               = local.common_tags
}
module "nginx" {
  source             = "./modules/ec2_instance"
  instance_type      = var.instance_type
  vpc_id             = data.aws_vpc.default.id
  public_subnet_id   = data.aws_subnet.default_public.id
  allow_http_ingress = true
  tags               = local.common_tags
}

# Simple data sources to use default VPC & one public subnet (for demos)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "default_public" {
  id = tolist(data.aws_subnets.default_public.ids)[0]
}