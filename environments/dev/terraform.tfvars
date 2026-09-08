aws_region  = "eu-west-2"
environment = "dev"

project_name = "platform-engineering"

cluster_name    = "platform-engineering-dev"
cluster_version = "1.31"

vpc_cidr = "10.0.0.0/16"

availability_zones = [
  "eu-west-2a",
  "eu-west-2b",
]

private_subnets = [
  "10.0.1.0/24",
  "10.0.2.0/24",
]

public_subnets = [
  "10.0.101.0/24",
  "10.0.102.0/24",
]

node_instance_types = [
  "t3.medium",
]

node_desired_size = 2
node_min_size     = 2
node_max_size     = 3

cluster_endpoint_public_access = false

enable_cluster_creator_admin_permissions = true

node_disk_size = 30
