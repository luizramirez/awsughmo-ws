variable "bucket_name" {
  type        = string
  description = "Globally unique bucket name"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply"
  default     = {}
}

