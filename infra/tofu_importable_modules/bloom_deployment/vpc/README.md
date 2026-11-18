# Network design:
#
# Provision a private and public subnet for each availability zone in the region. Only load
# balancers and NAT gateways are provisioned in the public subnets, everything else is provisioned
# in the private subnets. The Bloom ECS tasks need access to the internet so they can download their
# docker image and access their dependent services. Access is provided via NAT gateways. Access to
# AWS services is configured through AWS PrivateLink endpoints so that traffic stays in the AWS
# internal network rather than going over the internet.
#
# We get a /22 range (1,024 addresses total) and provision it into /26 blocks (64 addresses total,
# 59 usable [1]) for each subnet. This provisioning strategy supports up to 8 subnets in the region
# being deployed to. Assuming a base IP of 10.0.0.0, the subnet ranges will therefore be:
#
# cidr          | zone | type
# --------------|------|--------
# 10.0.0.0/26   |  a   | private
# 10.0.0.64/26  |  a   | public
# 10.0.0.128/26 |  b   | private
# 10.0.0.192/26 |  b   | public
# 10.0.1.0/26   |  c   | private
# 10.0.1.64/26  |  c   | public
# ...
#
#
# Requesting a VPC peering to an existing VPC is supported. This is used in scenarios where an
# existing database exists and will be used to import to the Bloom database. If this functionality
# is used, Bloom must be deployed into the same region as the existing VPC due to limitations of
# referencing security groups defined in the peered VPC [2].
#
# [1]:
#   From https://aws.amazon.com/vpc/faqs/:
#
#   > Amazon reserves the first four (4) IP addresses and the last one (1) IP address of every
#   > subnet for IP networking purposes. The minimum size of a subnet is a /28 (or 14 IP addresses.)
# [2]:
#   From https://docs.aws.amazon.com/vpc/latest/peering/vpc-peering-security-groups.html
#
#   > You can't reference the security group of a peer VPC that's in a different Region.