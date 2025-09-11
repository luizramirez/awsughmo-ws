# Latest Amazon Linux 2023 via SSM parameter (deterministic & safe)
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Security group (least privilege; optional HTTP)
resource "aws_security_group" "web" {
  name        = "tf101-web-sg"
  description = "Minimal SG for demo"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  count             = var.allow_http_ingress ? 1 : 0
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

# Egress all (typical)
resource "aws_vpc_security_group_egress_rule" "all_egress" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# IAM role for SSM (no SSH keys needed)
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm_role" {
  name               = "tf101-ec2-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

# Attach AWS managed policy for SSM
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name = "tf101-ec2-profile"
  role = aws_iam_role.ssm_role.name
}

# User data: install nginx & simple index
locals {
  user_data = <<-EOT
    #!/bin/bash
    dnf -y update
    dnf -y install nginx
    systemctl enable nginx
    echo "<h1>De la teoria a la practica: Construyendo infraestructura en AWS con Terraform </h1>" > /usr/share/nginx/html/index.html
    systemctl start nginx
  EOT
}

resource "aws_instance" "this" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.web.id]
  iam_instance_profile        = aws_iam_instance_profile.this.name
  associate_public_ip_address = true
  user_data                   = local.user_data

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  tags = merge(var.tags, { Name = "tf101-web" })
}

