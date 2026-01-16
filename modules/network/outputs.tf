output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private : s.id]
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}

output "private_route_table_id" {
  value = aws_route_table.private.id
}

# 선택 출력(없어도 되지만 import/확인에 도움)
output "igw_id" {
  value = aws_internet_gateway.this.id
}

output "nat_gateway_id" {
  value = try(aws_nat_gateway.this[0].id, null)
}
