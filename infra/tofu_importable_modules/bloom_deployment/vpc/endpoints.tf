# Create PrivateLink endpoints for all required AWS services.
resource "aws_vpc_endpoint" "aws_services" {
  for_each            = toset(local.aws_privatelink_services)
  region              = var.aws_region
  vpc_id              = aws_vpc.bloom.id
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true # required for the AWS SDKs to use this network path by default instead of through the public internet.
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  subnet_ids          = [for s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.aws_privatelink_services[each.key].id]
  tags = {
    Name = "bloom-${each.key}"
  }
}