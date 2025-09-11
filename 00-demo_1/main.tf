resource "aws_instance" "demo1" {
  ami           = "ami-0945610b37068d87a"
  instance_type = "t2.micro"
}

