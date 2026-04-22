terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC para el cluster Redis
resource "aws_vpc" "redis_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "sistema-pagos-vpc"
    Environment = var.environment
    Project     = "sistema-pagos"
  }
}

# Subnets privadas para Redis
resource "aws_subnet" "redis_subnet_1" {
  vpc_id            = aws_vpc.redis_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name        = "sistema-pagos-subnet-1"
    Environment = var.environment
    Project     = "sistema-pagos"
  }
}

resource "aws_subnet" "redis_subnet_2" {
  vpc_id            = aws_vpc.redis_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name        = "sistema-pagos-subnet-2"
    Environment = var.environment
    Project     = "sistema-pagos"
  }
}

# Security Group para Redis
resource "aws_security_group" "redis_sg" {
  name_prefix = "sistema-pagos-sg-"
  description = "Security group for sistema de pagos Redis cluster"
  vpc_id      = aws_vpc.redis_vpc.id

  # Puerto Redis (6379)
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Ajustar según necesidades de seguridad
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "sistema-pagos-security-group"
    Environment = var.environment
    Project     = "sistema-pagos"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Subnet group para ElastiCache
resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "sistema-pagos-subnet-group"
  subnet_ids = [aws_subnet.redis_subnet_1.id, aws_subnet.redis_subnet_2.id]

  tags = {
    Name        = "sistema-pagos-subnet-group"
    Environment = var.environment
    Project     = "sistema-pagos"
  }
}

# Parámetros de Redis
resource "aws_elasticache_parameter_group" "redis_params" {
  family = "redis7.x"
  name   = "sistema-pagos-params"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  parameter {
    name  = "notify-keyspace-events"
    value = "Ex"
  }
}

# Cluster de Redis
resource "aws_elasticache_replication_group" "redis_cluster" {
  replication_group_id       = "sistema-pagos-cluster"
  description                = "Redis cluster para sistema de pagos y catálogo de servicios"
  
  node_type                  = var.redis_node_type
  port                       = 6379
  parameter_group_name       = aws_elasticache_parameter_group.redis_params.name
  
  num_cache_clusters         = var.redis_num_nodes
  automatic_failover_enabled = true
  multi_az_enabled          = true
  
  subnet_group_name          = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids         = [aws_security_group.redis_sg.id]
  
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.redis_auth_token
  
  snapshot_retention_limit   = 7
  snapshot_window           = "03:00-05:00"
  maintenance_window        = "sun:05:00-sun:06:00"
  
  auto_minor_version_upgrade = true
  
  tags = {
    Name        = "sistema-pagos-cluster"
    Environment = var.environment
    Project     = "sistema-pagos"
  }
}
