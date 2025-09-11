variable "instance_type" {
  type        = string
  description = "EC2 instance type"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "public_subnet_id" {
  type        = string
  description = "Public subnet ID for the instance"
}

variable "allow_http_ingress" {
  type        = bool
  description = "Open TCP/80 from the internet (for demo)"
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags"
  default     = {}
}

