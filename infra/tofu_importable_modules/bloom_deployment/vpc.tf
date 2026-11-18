moved {
  from = aws_availability_zones.zones
  to   = module.vpc.aws_availability_zones.zones
}

moved {
  from = aws_vpc.bloom
  to   = module.vpc.aws_vpc.bloom
}

moved {
  from = aws_vpc_peering_connection.to_existing_vpc
  to   = module.vpc.aws_vpc_peering_connection.to_existing_vpc
}

moved {
  from = aws_vpc_peering_connection.to_existing_vpc
  to   = module.vpc.aws_vpc_peering_connection.to_existing_vpc
}

moved {
  from = aws_internet_gateway.bloom
  to   = module.vpc.aws_internet_gateway.bloom
}

moved {
  from = aws_subnet.public
  to   = module.vpc.aws_subnet.public
}

moved {
  from = aws_route_table.public
  to   = module.vpc.aws_route_table.public
}

moved {
  from = aws_route_table_association.public_subnet
  to   = module.vpc.aws_route_table_association.public_subnet
}

moved {
  from = aws_eip.nat
  to   = module.vpc.aws_eip.nat
}

moved {
  from = aws_nat_gateway.bloom
  to   = module.vpc.aws_nat_gateway.bloom
}

moved {
  from = aws_subnet.private
  to   = module.vpc.aws_subnet.private
}

moved {
  from = aws_route_table.private
  to   = module.vpc.aws_route_table.private
}

moved {
  from = aws_route_table_association.private_subnet
  to   = module.vpc.aws_route_table_association.private_subnet
}

moved {
  from = aws_route.private_nat
  to   = module.vpc.aws_route.private_nat
}

moved {
  from = aws_route.vpc_peer
  to   = module.vpc.aws_route.vpc_peer
}

moved {
  from = aws_vpc_endpoint.aws_services
  to   = module.vpc.aws_vpc_endpoint.aws_services
}

moved {
  from = aws_security_group.aws_privatelink_services
  to   = module.vpc.aws_security_group.aws_privatelink_services
}

moved {
  from = aws_vpc_security_group_ingress_rule.aws_privatelink
  to   = module.vpc.aws_vpc_security_group_ingress_rule.aws_privatelink
}

moved {
  from = aws_vpc_security_group_egress_rule.aws_privatelink
  to   = module.vpc.aws_vpc_security_group_egress_rule.aws_privatelink
}

moved {
  from = aws_security_group.bloom
  to   = module.vpc.aws_security_group.bloom
}

moved {
  from = aws_vpc_security_group_ingress_rule.from_internet
  to   = module.vpc.aws_vpc_security_group_ingress_rule.from_internet
}

moved {
  from = aws_vpc_security_group_ingress_rule.from_vpc_peering
  to   = module.vpc.aws_vpc_security_group_ingress_rule.from_vpc_peering
}

moved {
  from = aws_vpc_security_group_ingress_rule.bloom
  to   = module.vpc.aws_vpc_security_group_ingress_rule.bloom
}

moved {
  from = aws_vpc_security_group_egress_rule.bloom
  to   = module.vpc.aws_vpc_security_group_egress_rule.bloom
}

moved {
  from = aws_vpc_security_group_egress_rule.to_nat
  to   = module.vpc.aws_vpc_security_group_egress_rule.to_nat
}
