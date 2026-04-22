variable "aws_region" {
  description = "Región de AWS para desplegar los recursos"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente de despliegue"
  type        = string
  default     = "production"
}

variable "redis_node_type" {
  description = "Tipo de instancia para los nodos Redis del sistema de pagos"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_nodes" {
  description = "Número de nodos en el cluster Redis del sistema de pagos"
  type        = number
  default     = 2
}

variable "redis_auth_token" {
  description = "Token de autenticación para Redis del sistema de pagos"
  type        = string
  sensitive   = true
  default     = ""
}
