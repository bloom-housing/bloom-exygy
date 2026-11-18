moved {
  from = aws_availability_zones.zones
  to   = module.vpc.aws_availability_zones.zones
}
# data "aws_availability_zones" "zones" {
#   region = var.aws_region
#   state  = "available"

#   lifecycle {
#     postcondition {
#       # At the time of writing, the largest region is us-east-1 with 6 availability zones.
#       condition     = length(self.names) <= 8
#       error_message = "The IP provisioning strategy does not support more than 8 availability zones."
#     }
#   }
# }

moved {
  from = aws_vpc.bloom
  to   = module.vpc.aws_vpc.bloom
}
# resource "aws_vpc" "bloom" {
#   region               = var.aws_region
#   cidr_block           = var.vpc_cidr_range
#   enable_dns_support   = true
#   enable_dns_hostnames = true
#   tags = {
#     Name = "bloom"
#   }
# }

moved {
  from = aws_vpc_peering_connection.to_existing_vpc
  to   = module.vpc.aws_vpc_peering_connection.to_existing_vpc
}

# Set up the VPC peering connection if specified.
# resource "aws_vpc_peering_connection" "to_existing_vpc" {
#   count = var.vpc_peering_settings == null ? 0 : 1

#   region = var.aws_region
#   vpc_id = aws_vpc.bloom.id

#   peer_owner_id = var.vpc_peering_settings.aws_account_number
#   peer_vpc_id   = var.vpc_peering_settings.vpc_id

#   tags = {
#     Name = "to-existing-vpc"
#   }
# }

moved {
  from = aws_vpc_peering_connection.to_existing_vpc
  to   = module.vpc.aws_vpc_peering_connection.to_existing_vpc
}
# data "aws_vpc_peering_connection" "to_existing_vpc" {
#   count  = var.vpc_peering_settings == null ? 0 : 1
#   vpc_id = aws_vpc.bloom.id
#   id     = aws_vpc_peering_connection.to_existing_vpc[0].id
#   lifecycle {
#     postcondition {
#       condition     = self.status == "active"
#       error_message = "VPC peering not accepted. Skipping creation of dependent resources."
#     }
#   }
# }

moved {
  from = aws_internet_gateway.bloom
  to   = module.vpc.aws_internet_gateway.bloom
}
# What makes a AWS subnet public is a direct route to the internet. This is controlled through the
# route tables attached to each subnet. By default each route table has a 'local' route for cidr
# ranges used by the VPC. Add 'catch-all' route for 0.0.0.0/0 that routes to the VPC internet
# gateway.
# resource "aws_internet_gateway" "bloom" {
#   region = var.aws_region
#   vpc_id = aws_vpc.bloom.id
# }

moved {
  from = aws_subnet.public
  to   = module.vpc.aws_subnet.public
}
# resource "aws_subnet" "public" {
#   for_each                = local.public_subnets
#   vpc_id                  = aws_vpc.bloom.id
#   availability_zone       = each.key
#   cidr_block              = each.value
#   map_public_ip_on_launch = false
#   tags = {
#     Name = "bloom-public-${each.key}"
#   }
# }

moved {
  from = aws_route_table.public
  to   = module.vpc.aws_route_table.public
}
# resource "aws_route_table" "public" {
#   region = var.aws_region
#   vpc_id = aws_vpc.bloom.id
#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.bloom.id
#   }
#   tags = {
#     Name = "bloom-public"
#   }
# }

moved {
  from = aws_route_table_association.public_subnet
  to   = module.vpc.aws_route_table_association.public_subnet
}
# resource "aws_route_table_association" "public_subnet" {
#   for_each       = aws_subnet.public
#   region         = var.aws_region
#   subnet_id      = each.value.id
#   route_table_id = aws_route_table.public.id
# }
# ECS tasks in the private subnets still need access to the internet. This is provided by a NAT
# gateway. A NAT gateway is a zonal resource so provision one in each availability zone. Each
# private subnet needs a route table with a similar 'catch-all' route, but instead of going to the
# VPC internet gateway, it goes to the NAT gateway in the zone.

moved {
  from = aws_eip.nat
  to   = module.vpc.aws_eip.nat
}
# resource "aws_eip" "nat" {
#   for_each = aws_subnet.public
#   region   = var.aws_region
#   domain   = "vpc"
# }

moved {
  from = aws_nat_gateway.bloom
  to   = module.vpc.aws_nat_gateway.bloom
}
# resource "aws_nat_gateway" "bloom" {
#   for_each          = aws_subnet.public
#   region            = var.aws_region
#   connectivity_type = "public"
#   subnet_id         = each.value.id
#   allocation_id     = aws_eip.nat[each.key].id
#   tags = {
#     Name = "bloom-nat-${each.key}"
#   }
# }

moved {
  from = aws_subnet.private
  to   = module.vpc.aws_subnet.private
}
# Create private subnets.
# resource "aws_subnet" "private" {
#   for_each                = local.private_subnets
#   vpc_id                  = aws_vpc.bloom.id
#   availability_zone       = each.key
#   cidr_block              = each.value
#   map_public_ip_on_launch = false
#   tags = {
#     Name = "bloom-private-${each.key}"
#   }
# }

moved {
  from = aws_route_table.private
  to   = module.vpc.aws_route_table.private
}
# resource "aws_route_table" "private" {
#   for_each = aws_subnet.private
#   region   = var.aws_region
#   vpc_id   = aws_vpc.bloom.id
#   tags = {
#     Name = "bloom-private-${each.key}"
#   }
# }

moved {
  from = aws_route_table_association.private_subnet
  to   = module.vpc.aws_route_table_association.private_subnet
}
# resource "aws_route_table_association" "private_subnet" {
#   for_each       = aws_subnet.private
#   region         = var.aws_region
#   subnet_id      = each.value.id
#   route_table_id = aws_route_table.private[each.key].id
# }

moved {
  from = aws_route.private_nat
  to   = module.vpc.aws_route.private_nat
}
# resource "aws_route" "private_nat" {
#   for_each               = aws_subnet.private
#   region                 = var.aws_region
#   route_table_id         = aws_route_table.private[each.key].id
#   destination_cidr_block = "0.0.0.0/0"
#   nat_gateway_id         = aws_nat_gateway.bloom[each.key].id
# }

moved {
  from = aws_route.vpc_peer
  to   = module.vpc.aws_route.vpc_peer
}
# resource "aws_route" "vpc_peer" {
#   for_each                  = var.vpc_peering_settings == null ? {} : aws_subnet.private
#   region                    = var.aws_region
#   route_table_id            = aws_route_table.private[each.key].id
#   destination_cidr_block    = var.vpc_peering_settings.allowed_cidr_range
#   vpc_peering_connection_id = aws_vpc_peering_connection.to_existing_vpc[0].id
# }

moved {
  from = aws_vpc_endpoint.aws_services
  to   = module.vpc.aws_vpc_endpoint.aws_services
}
# Create PrivateLink endpoints for all required AWS services.
# resource "aws_vpc_endpoint" "aws_services" {
#   for_each            = toset(local.aws_privatelink_services)
#   region              = var.aws_region
#   vpc_id              = aws_vpc.bloom.id
#   vpc_endpoint_type   = "Interface"
#   private_dns_enabled = true # required for the AWS SDKs to use this network path by default instead of through the public internet.
#   service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
#   subnet_ids          = [for s in aws_subnet.private : s.id]
#   security_group_ids  = [aws_security_group.aws_privatelink_services[each.key].id]
#   tags = {
#     Name = "bloom-${each.key}"
#   }
# }

moved {
  from = aws_security_group.aws_privatelink_services
  to   = module.vpc.aws_security_group.aws_privatelink_services
}
# resource "aws_security_group" "aws_privatelink_services" {
#   for_each    = toset(local.aws_privatelink_services)
#   region      = var.aws_region
#   vpc_id      = aws_vpc.bloom.id
#   name        = "${each.key}-privatelink-endpoint"
#   description = "Rules for ${each.key} vpc PrivateLink endpoint"
# }

moved {
  from = aws_vpc_security_group_ingress_rule.aws_privatelink
  to   = module.vpc.aws_vpc_security_group_ingress_rule.aws_privatelink
}
# resource "aws_vpc_security_group_ingress_rule" "aws_privatelink" {
#   for_each = {
#     for u in local.aws_privatelink_users : "${u.bloom_sg}_to_${u.aws_service}" => u
#   }
#   region                       = var.aws_region
#   security_group_id            = aws_security_group.aws_privatelink_services[each.value.aws_service].id
#   referenced_security_group_id = aws_security_group.bloom[each.value.bloom_sg].id
#   ip_protocol                  = "tcp"
#   from_port                    = 443
#   to_port                      = 443
#   tags = {
#     Name = "${each.value.bloom_sg}-allow"
#   }
# }

moved {
  from = aws_vpc_security_group_egress_rule.aws_privatelink
  to   = module.vpc.aws_vpc_security_group_egress_rule.aws_privatelink
}
# resource "aws_vpc_security_group_egress_rule" "aws_privatelink" {
#   for_each = {
#     for u in local.aws_privatelink_users : "${u.bloom_sg}_to_${u.aws_service}" => u
#   }
#   region                       = var.aws_region
#   security_group_id            = aws_security_group.bloom[each.value.bloom_sg].id
#   referenced_security_group_id = aws_security_group.aws_privatelink_services[each.value.aws_service].id
#   ip_protocol                  = "tcp"
#   from_port                    = 443
#   to_port                      = 443
#   tags = {
#     Name = "${each.value.aws_service}-allow"
#   }
# }

moved {
  from = aws_security_group.bloom
  to   = module.vpc.aws_security_group.bloom
}
# Create security groups and rules for the Bloom services.
# resource "aws_security_group" "bloom" {
#   for_each    = local.bloom_security_groups
#   region      = var.aws_region
#   vpc_id      = aws_vpc.bloom.id
#   name        = "bloom-${each.key}"
#   description = "Rules for Bloom ${each.key}."
#   tags = {
#     Name = "bloom-${each.key}"
#   }
# }

moved {
  from = aws_vpc_security_group_ingress_rule.from_internet
  to   = module.vpc.aws_vpc_security_group_ingress_rule.from_internet
}
# resource "aws_vpc_security_group_ingress_rule" "from_internet" {
#   for_each          = { for sg, config in local.bloom_security_groups : sg => config if config.ingress != null && config.ingress.internet }
#   region            = var.aws_region
#   security_group_id = aws_security_group.bloom[each.key].id
#   cidr_ipv4         = "0.0.0.0/0"
#   ip_protocol       = "tcp"
#   from_port         = each.value.ingress.port
#   to_port           = each.value.ingress.port
#   tags = {
#     Name = "internet-allow"
#   }
# }

moved {
  from = aws_vpc_security_group_ingress_rule.from_vpc_peering
  to   = module.vpc.aws_vpc_security_group_ingress_rule.from_vpc_peering
}
# resource "aws_vpc_security_group_ingress_rule" "from_vpc_peering" {
#   for_each                     = { for sg, config in local.bloom_security_groups : sg => config if config.ingress != null && config.ingress.vpc_peering }
#   region                       = var.aws_region
#   security_group_id            = aws_security_group.bloom[each.key].id
#   referenced_security_group_id = "${var.vpc_peering_settings.aws_account_number}/${var.vpc_peering_settings.allowed_security_group_id}"
#   ip_protocol                  = "tcp"
#   from_port                    = each.value.ingress.port
#   to_port                      = each.value.ingress.port
#   tags = {
#     Name = "vpc-peering-allow"
#   }
# }

moved {
  from = aws_vpc_security_group_ingress_rule.bloom
  to   = module.vpc.aws_vpc_security_group_ingress_rule.bloom
}
# resource "aws_vpc_security_group_ingress_rule" "bloom" {
#   for_each = {
#     for u in local.bloom_users : "${u.from}_to_${u.to}" => u
#   }
#   region                       = var.aws_region
#   security_group_id            = aws_security_group.bloom[each.value.to].id
#   referenced_security_group_id = aws_security_group.bloom[each.value.from].id
#   ip_protocol                  = "tcp"
#   from_port                    = local.bloom_security_groups[each.value.to].ingress.port
#   to_port                      = local.bloom_security_groups[each.value.to].ingress.port
#   tags = {
#     Name = "${each.value.from}-allow"
#   }
# }

moved {
  from = aws_vpc_security_group_egress_rule.bloom
  to   = module.vpc.aws_vpc_security_group_egress_rule.bloom
}
# resource "aws_vpc_security_group_egress_rule" "bloom" {
#   for_each = {
#     for u in local.bloom_users : "${u.from}_to_${u.to}" => u
#   }
#   region                       = var.aws_region
#   security_group_id            = aws_security_group.bloom[each.value.from].id
#   referenced_security_group_id = aws_security_group.bloom[each.value.to].id
#   ip_protocol                  = "tcp"
#   from_port                    = local.bloom_security_groups[each.value.to].ingress.port
#   to_port                      = local.bloom_security_groups[each.value.to].ingress.port
#   tags = {
#     Name = "${each.value.to}-allow"
#   }
# }

moved {
  from = aws_vpc_security_group_egress_rule.to_nat
  to   = module.vpc.aws_vpc_security_group_egress_rule.to_nat
}
# resource "aws_vpc_security_group_egress_rule" "to_nat" {
#   for_each          = toset([for sg, config in local.bloom_security_groups : sg if config.egress != null && config.egress.nat])
#   region            = var.aws_region
#   security_group_id = aws_security_group.bloom[each.key].id
#   cidr_ipv4         = "0.0.0.0/0"
#   ip_protocol       = "tcp"
#   from_port         = 443
#   to_port           = 443
#   tags = {
#     Name = "nat-allow"
#   }
# }
