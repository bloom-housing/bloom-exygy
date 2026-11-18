output "aws_vpc_id" {
  value = aws_vpc.bloom.id
}

output "aws_private_subnet_ids" {
  value = [for v in aws_subnet.private : v.id]
}

output "aws_public_subnet_ids" {
  value = [for v in aws_subnet.public : v.id]
}

output "aws_security_groups" {
  value = { for key, sg in aws_security_group.bloom : key => sg.id }
}

output "aws_vpc_service_endpoints" {
  value = { for key, sv in aws_vpc_endpoint.aws_services : key => sv }
}

output "aws_vpc_secrets_manager_endpoint" {
  value = aws_vpc_endpoint.aws_services["secretsmanager"]
}

output "aws_route_table_association_private_subnet" {
  value = aws_route_table_association.private_subnet
}
