module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.2"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_private_access      = var.cluster_endpoint_private_access
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  cluster_enabled_log_types = var.cluster_enabled_log_types

  cluster_encryption_config = {
    resources = ["secrets"]
  }

  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  access_entries = var.cluster_admin_principal_arn == null ? {} : {
    platform_admin = {
      principal_arn = var.cluster_admin_principal_arn

      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  eks_managed_node_groups = {
    default = {
      desired_size = var.node_desired_size
      min_size     = var.node_min_size
      max_size     = var.node_max_size

      instance_types = var.node_instance_types

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"

          ebs = {
            encrypted             = true
            volume_type           = "gp3"
            volume_size           = var.node_disk_size
            delete_on_termination = true
          }
        }
      }

      labels = {
        environment = var.environment
        workload    = "platform"
      }

      tags = var.tags
    }
  }

  tags = var.tags
}