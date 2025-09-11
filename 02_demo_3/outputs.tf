output "api_url" {
  description = "Endpoint público para POST /chat"
  value       = "${aws_apigatewayv2_api.http_api.api_endpoint}/chat"
}

output "lambda_name" {
  value = aws_lambda_function.chatbot.function_name
}
output "website_url" {
  description = "URL del sitio estático en S3"
  value       = aws_s3_bucket_website_configuration.site.website_endpoint
}

output "website_bucket" {
  description = "Nombre del bucket S3 del sitio"
  value       = aws_s3_bucket.site.bucket
}
