output "replication_group_id" {
  value = aws_elasticache_replication_group.this.replication_group_id
}

output "configuration_endpoint" {
  value = aws_elasticache_replication_group.this.configuration_endpoint_address
}

output "reader_endpoint" {
  value = aws_elasticache_replication_group.this.reader_endpoint_address
}

output "security_group_id" {
  value = aws_security_group.this.id
}

output "subnet_group_name" {
  value = aws_elasticache_subnet_group.this.name
}
