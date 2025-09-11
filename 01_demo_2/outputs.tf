output "s3_bucket_id" {
  description = "S3 bucket name"
  value       = module.bucket.bucket_id
}

output "ec2_public_ip" {
  description = "Public IP of EC2 instance"
  value       = module.web.public_ip
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = module.web.instance_id
}
