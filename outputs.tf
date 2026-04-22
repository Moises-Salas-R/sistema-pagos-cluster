output "redis_endpoint" {
  description = "Endpoint principal del cluster Redis del sistema de pagos"
  value       = aws_elasticache_replication_group.redis_cluster.primary_endpoint_address
}

output "redis_port" {
  description = "Puerto del cluster Redis del sistema de pagos"
  value       = aws_elasticache_replication_group.redis_cluster.port
}

output "redis_auth_token" {
  description = "Token de autenticación de Redis del sistema de pagos"
  value       = var.redis_auth_token
  sensitive   = true
}

output "vpc_id" {
  description = "ID de la VPC del sistema de pagos"
  value       = aws_vpc.redis_vpc.id
}

output "security_group_id" {
  description = "ID del security group de Redis del sistema de pagos"
  value       = aws_security_group.redis_sg.id
}

output "connection_string" {
  description = "String de conexión para Redis del sistema de pagos"
  value       = "redis://${aws_elasticache_replication_group.redis_cluster.primary_endpoint_address}:${aws_elasticache_replication_group.redis_cluster.port}"
  sensitive   = true
}
