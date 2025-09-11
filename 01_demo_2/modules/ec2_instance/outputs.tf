output "public_ip" {
  value       = aws_instance.this.public_ip
  description = "Public IP"
}

output "instance_id" {
  value       = aws_instance.this.id
  description = "Instance ID"
}