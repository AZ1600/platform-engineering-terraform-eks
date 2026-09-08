module "network" {
  source = "../../modules/network"

  name = "${local.name_prefix}-vpc"
  cidr = var.vpc_cidr

  availability_zones = var.availability_zones
  private_subnets    = var.private_subnets
  public_subnets     = var.public_subnets

  tags = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids

  environment = var.environment

  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions
  cluster_admin_principal_arn              = var.cluster_admin_principal_arn

  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  node_disk_size      = var.node_disk_size

  tags = local.common_tags
}
