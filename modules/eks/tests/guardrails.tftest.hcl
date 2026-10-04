mock_provider "aws" {}

override_module {
  target = module.eks

  outputs = {
    cluster_name     = "platform-test"
    cluster_endpoint = "https://example.invalid"
  }
}

variables {
  cluster_name    = "platform-test"
  cluster_version = "1.31"

  vpc_id = "vpc-0123456789abcdef0"

  subnet_ids = [
    "subnet-0123456789abcdef0",
    "subnet-0123456789abcdef1",
  ]

  environment = "test"

  node_instance_types = [
    "t3.medium",
  ]

  node_desired_size = 2
  node_min_size     = 2
  node_max_size     = 3

  tags = {
    Environment = "test"
    ManagedBy   = "Terraform"
  }
}

run "reject_public_api_without_cidrs" {
  command = plan

  variables {
    cluster_endpoint_public_access       = true
    cluster_endpoint_public_access_cidrs = []
  }

  expect_failures = [
    var.cluster_endpoint_public_access_cidrs,
  ]
}

run "reject_unrestricted_ipv4_public_api" {
  command = plan

  variables {
    cluster_endpoint_public_access = true

    cluster_endpoint_public_access_cidrs = [
      "0.0.0.0/0",
    ]
  }

  expect_failures = [
    var.cluster_endpoint_public_access_cidrs,
  ]
}

run "reject_unrestricted_ipv6_public_api" {
  command = plan

  variables {
    cluster_endpoint_public_access = true

    cluster_endpoint_public_access_cidrs = [
      "::/0",
    ]
  }

  expect_failures = [
    var.cluster_endpoint_public_access_cidrs,
  ]
}

run "reject_desired_nodes_below_minimum" {
  command = plan

  variables {
    node_min_size     = 2
    node_desired_size = 1
    node_max_size     = 3
  }

  expect_failures = [
    var.node_desired_size,
  ]
}

run "reject_desired_nodes_above_maximum" {
  command = plan

  variables {
    node_min_size     = 1
    node_desired_size = 4
    node_max_size     = 3
  }

  expect_failures = [
    var.node_desired_size,
  ]
}

run "reject_negative_minimum_nodes" {
  command = plan

  variables {
    node_min_size     = -1
    node_desired_size = 1
    node_max_size     = 3
  }

  expect_failures = [
    var.node_min_size,
  ]
}

run "reject_empty_instance_types" {
  command = plan

  variables {
    node_instance_types = []
  }

  expect_failures = [
    var.node_instance_types,
  ]
}

run "reject_invalid_control_plane_log_type" {
  command = plan

  variables {
    cluster_enabled_log_types = [
      "api",
      "audit",
      "invalid-log-type",
    ]
  }

  expect_failures = [
    var.cluster_enabled_log_types,
  ]
}