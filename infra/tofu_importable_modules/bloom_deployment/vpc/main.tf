locals {
  zones = data.aws_availability_zones.zones.names

  # VPC range is a /22, each subnet gets a /26
  newbits = 26 - 22

  # Take even index ranges.
  private_subnets = zipmap(
    local.zones,
    [for i in range(0, (length(local.zones) * 2) - 1, 2) : cidrsubnet(var.vpc_cidr_range, local.newbits, i)]
  )
  # Take odd index ranges.
  public_subnets = zipmap(
    local.zones,
    [for i in range(1, length(local.zones) * 2, 2) : cidrsubnet(var.vpc_cidr_range, local.newbits, i)]
  )
}


locals {
  # List of AWS services that PrivateLink endpoints will be created for. This keeps traffic from
  # Bloom services to the AWS services internal to the VPC instead of going over the public
  # internet.
  aws_privatelink_services = ["secretsmanager", "rds", "data-servicediscovery", "aps-workspaces"]
  aws_privatelink_users = flatten([
    for sg, config in local.bloom_security_groups : [
      for aws_service in config.egress == null ? [] : config.egress.privatelink_services : {
        aws_service = aws_service
        bloom_sg    = sg
      }
    ]
  ])

  # List of security groups to create for the Bloom services.
  bloom_security_groups = merge({
    "db" : {
      ingress = {
        internet    = false
        vpc_peering = var.vpc_peering_settings != null
        port        = 5432
      }
      egress = null
    }
    "dbinit" : {
      ingress = null
      egress = {
        privatelink_services = ["secretsmanager"] # to read DB master user secret.
        nat                  = true               # to download container image from GitHub.
        security_groups      = ["db"]
      }
    }
    "lb" : {
      ingress = {
        internet    = true
        vpc_peering = false
        port        = 443
      }
      egress = {
        privatelink_services = []
        nat                  = false
        security_groups      = ["site-partners", "site-public"]
      }
    }
    "api" : {
      ingress = {
        internet    = false
        vpc_peering = false
        port        = 3100
      }
      egress = {
        privatelink_services = [
          "secretsmanager", # to read JWT signing key and Google Translate key.
          "rds",            # to generate an auth token for bloom_api DB user.
          "aps-workspaces", # to write metrics.
        ]
        nat             = true # to download container image from GitHub.
        security_groups = ["db"]
      }
    }
    "site-partners" : {
      ingress = {
        internet    = false
        vpc_peering = false
        port        = 3001
      }
      egress = {
        privatelink_services = [
          "secretsmanager", # to read Mapbox API key
          "aps-workspaces"  # to write metrics.
        ]
        nat             = true # to download container image from GitHub.
        security_groups = ["api"]
      }
    }
    "site-public" : {
      ingress = {
        internet    = false
        vpc_peering = false
        port        = 3000
      }
      egress = {
        privatelink_services = [
          "secretsmanager", # to read Mapbox API key
          "aps-workspaces"  # to write metrics.
        ]
        nat             = true # to download container image from GitHub.
        security_groups = ["api"]
      }
    }
    "cloudshell" : {
      ingress = null
      egress = {
        privatelink_services = ["rds", "data-servicediscovery"] # see infra/aws_deployment_guide/7_operations_playbook.md for the APIs used.
        nat                  = false
        security_groups      = ["api", "db"]
      }
    }
    }, var.bloom_dbseed_image == "" ? {} : {
    "dbseed" : {
      ingress = null
      egress = {
        privatelink_services = ["rds"] # to generate an auth token for bloom_api DB user.
        nat                  = true    # to download container image from GitHub.
        security_groups      = ["db"]
      }
    }
  })
  bloom_users = flatten([
    for sg, config in local.bloom_security_groups : [
      for to_sg in config.egress == null ? [] : config.egress.security_groups : {
        from = sg
        to   = to_sg
      }
    ]
  ])
}

data "aws_availability_zones" "zones" {
  region = var.aws_region
  state  = "available"

  lifecycle {
    postcondition {
      # At the time of writing, the largest region is us-east-1 with 6 availability zones.
      condition     = length(self.names) <= 8
      error_message = "The IP provisioning strategy does not support more than 8 availability zones."
    }
  }
}

resource "aws_vpc" "bloom" {
  region               = var.aws_region
  cidr_block           = var.vpc_cidr_range
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "bloom"
  }
}

# Set up the VPC peering connection if specified.
resource "aws_vpc_peering_connection" "to_existing_vpc" {
  count = var.vpc_peering_settings == null ? 0 : 1

  region = var.aws_region
  vpc_id = aws_vpc.bloom.id

  peer_owner_id = var.vpc_peering_settings.aws_account_number
  peer_vpc_id   = var.vpc_peering_settings.vpc_id

  tags = {
    Name = "to-existing-vpc"
  }
}

data "aws_vpc_peering_connection" "to_existing_vpc" {
  count  = var.vpc_peering_settings == null ? 0 : 1
  vpc_id = aws_vpc.bloom.id
  id     = aws_vpc_peering_connection.to_existing_vpc[0].id
  lifecycle {
    postcondition {
      condition     = self.status == "active"
      error_message = "VPC peering not accepted. Skipping creation of dependent resources."
    }
  }
}

# What makes a AWS subnet public is a direct route to the internet. This is controlled through the
# route tables attached to each subnet. By default each route table has a 'local' route for cidr
# ranges used by the VPC. Add 'catch-all' route for 0.0.0.0/0 that routes to the VPC internet
# gateway.
resource "aws_internet_gateway" "bloom" {
  region = var.aws_region
  vpc_id = aws_vpc.bloom.id
}

resource "aws_subnet" "public" {
  for_each                = local.public_subnets
  vpc_id                  = aws_vpc.bloom.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false
  tags = {
    Name = "bloom-public-${each.key}"
  }
}

resource "aws_route_table" "public" {
  region = var.aws_region
  vpc_id = aws_vpc.bloom.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bloom.id
  }
  tags = {
    Name = "bloom-public"
  }
}

resource "aws_route_table_association" "public_subnet" {
  for_each       = aws_subnet.public
  region         = var.aws_region
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ECS tasks in the private subnets still need access to the internet. This is provided by a NAT
# gateway. A NAT gateway is a zonal resource so provision one in each availability zone. Each
# private subnet needs a route table with a similar 'catch-all' route, but instead of going to the
# VPC internet gateway, it goes to the NAT gateway in the zone.
resource "aws_eip" "nat" {
  for_each = aws_subnet.public
  region   = var.aws_region
  domain   = "vpc"
}

resource "aws_nat_gateway" "bloom" {
  for_each          = aws_subnet.public
  region            = var.aws_region
  connectivity_type = "public"
  subnet_id         = each.value.id
  allocation_id     = aws_eip.nat[each.key].id
  tags = {
    Name = "bloom-nat-${each.key}"
  }
}

# Create private subnets.
resource "aws_subnet" "private" {
  for_each                = local.private_subnets
  vpc_id                  = aws_vpc.bloom.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false
  tags = {
    Name = "bloom-private-${each.key}"
  }
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  region   = var.aws_region
  vpc_id   = aws_vpc.bloom.id
  tags = {
    Name = "bloom-private-${each.key}"
  }
}

resource "aws_route_table_association" "private_subnet" {
  for_each       = aws_subnet.private
  region         = var.aws_region
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_route" "private_nat" {
  for_each               = aws_subnet.private
  region                 = var.aws_region
  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.bloom[each.key].id
}

resource "aws_route" "vpc_peer" {
  for_each                  = var.vpc_peering_settings == null ? {} : aws_subnet.private
  region                    = var.aws_region
  route_table_id            = aws_route_table.private[each.key].id
  destination_cidr_block    = var.vpc_peering_settings.allowed_cidr_range
  vpc_peering_connection_id = aws_vpc_peering_connection.to_existing_vpc[0].id
}


resource "aws_security_group" "aws_privatelink_services" {
  for_each    = toset(local.aws_privatelink_services)
  region      = var.aws_region
  vpc_id      = aws_vpc.bloom.id
  name        = "${each.key}-privatelink-endpoint"
  description = "Rules for ${each.key} vpc PrivateLink endpoint"
}

resource "aws_vpc_security_group_ingress_rule" "aws_privatelink" {
  for_each = {
    for u in local.aws_privatelink_users : "${u.bloom_sg}_to_${u.aws_service}" => u
  }
  region                       = var.aws_region
  security_group_id            = aws_security_group.aws_privatelink_services[each.value.aws_service].id
  referenced_security_group_id = aws_security_group.bloom[each.value.bloom_sg].id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  tags = {
    Name = "${each.value.bloom_sg}-allow"
  }
}

resource "aws_vpc_security_group_egress_rule" "aws_privatelink" {
  for_each = {
    for u in local.aws_privatelink_users : "${u.bloom_sg}_to_${u.aws_service}" => u
  }
  region                       = var.aws_region
  security_group_id            = aws_security_group.bloom[each.value.bloom_sg].id
  referenced_security_group_id = aws_security_group.aws_privatelink_services[each.value.aws_service].id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  tags = {
    Name = "${each.value.aws_service}-allow"
  }
}

# Create security groups and rules for the Bloom services.
# TODO move into security groups module
resource "aws_security_group" "bloom" {
  for_each    = local.bloom_security_groups
  region      = var.aws_region
  vpc_id      = aws_vpc.bloom.id
  name        = "bloom-${each.key}"
  description = "Rules for Bloom ${each.key}."
  tags = {
    Name = "bloom-${each.key}"
  }
}

resource "aws_vpc_security_group_ingress_rule" "from_internet" {
  for_each          = { for sg, config in local.bloom_security_groups : sg => config if config.ingress != null && config.ingress.internet }
  region            = var.aws_region
  security_group_id = aws_security_group.bloom[each.key].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = each.value.ingress.port
  to_port           = each.value.ingress.port
  tags = {
    Name = "internet-allow"
  }
}

resource "aws_vpc_security_group_ingress_rule" "from_vpc_peering" {
  for_each                     = { for sg, config in local.bloom_security_groups : sg => config if config.ingress != null && config.ingress.vpc_peering }
  region                       = var.aws_region
  security_group_id            = aws_security_group.bloom[each.key].id
  referenced_security_group_id = "${var.vpc_peering_settings.aws_account_number}/${var.vpc_peering_settings.allowed_security_group_id}"
  ip_protocol                  = "tcp"
  from_port                    = each.value.ingress.port
  to_port                      = each.value.ingress.port
  tags = {
    Name = "vpc-peering-allow"
  }
}

resource "aws_vpc_security_group_ingress_rule" "bloom" {
  for_each = {
    for u in local.bloom_users : "${u.from}_to_${u.to}" => u
  }
  region                       = var.aws_region
  security_group_id            = aws_security_group.bloom[each.value.to].id
  referenced_security_group_id = aws_security_group.bloom[each.value.from].id
  ip_protocol                  = "tcp"
  from_port                    = local.bloom_security_groups[each.value.to].ingress.port
  to_port                      = local.bloom_security_groups[each.value.to].ingress.port
  tags = {
    Name = "${each.value.from}-allow"
  }
}

resource "aws_vpc_security_group_egress_rule" "bloom" {
  for_each = {
    for u in local.bloom_users : "${u.from}_to_${u.to}" => u
  }
  region                       = var.aws_region
  security_group_id            = aws_security_group.bloom[each.value.from].id
  referenced_security_group_id = aws_security_group.bloom[each.value.to].id
  ip_protocol                  = "tcp"
  from_port                    = local.bloom_security_groups[each.value.to].ingress.port
  to_port                      = local.bloom_security_groups[each.value.to].ingress.port
  tags = {
    Name = "${each.value.to}-allow"
  }
}

resource "aws_vpc_security_group_egress_rule" "to_nat" {
  for_each          = toset([for sg, config in local.bloom_security_groups : sg if config.egress != null && config.egress.nat])
  region            = var.aws_region
  security_group_id = aws_security_group.bloom[each.key].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  tags = {
    Name = "nat-allow"
  }
}
