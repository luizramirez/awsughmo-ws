variable "project_name" {
  description = "Nombre base para recursos"
  type        = string
  default     = "tf-bedrock-chatbot"
}

variable "aws_region" {
  description = "Región (elige una con Bedrock habilitado; p.ej. us-west-2 o us-east-1)"
  type        = string
  default     = "us-west-2"
}

variable "bedrock_model_id" {
  description = "ID del modelo de Bedrock a invocar"
  type        = string
  # Asegúrate de tener acceso habilitado a este modelo en Bedrock -> Model access
  default = "anthropic.claude-3-5-sonnet-20240620-v1:0"
}

variable "temperature" {
  description = "Creatividad del modelo (0.0 - 1.0)"
  type        = number
  default     = 0.2
}

variable "max_tokens" {
  description = "Límite de tokens de salida"
  type        = number
  default     = 400
}

variable "cors_allowed_origin" {
  description = "Origen permitido para CORS (para pruebas, *)."
  type        = string
  default     = "*"
}

variable "frontend_allowed_origin" {
  description = "Origen del frontend para CORS (se completa después de crear el website). Usa * en el workshop."
  type        = string
  default     = "*"
}

variable "vision_model_id" {
  description = "Modelo multimodal en Bedrock (visión). Claude 3.5 Sonnet soporta imágenes."
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20240620-v1:0"
}
