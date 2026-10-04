mock_provider "aws" {}

override_module {
  target = module.vpc

  outputs = {
    vpc_id = "vpc-0123456789abcdef0"

    private_subnets = [
      "subnet-0123456789abcdef0",
      "subnet-0123456789abcdef1",
    ]

    public_subnets = [
      "subnet-0123456789abcdef2",
      "subnet-0123456789abcdef3",
    ]
  }
}

variables {
  name = "platform-test-vpc"
  cidr = "10.0.0.0/16"

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

  tags = {
    Environment = "test"
    ManagedBy   = "Terraform"
  }
}

run "reject_single_availability_zone" {
  command = plan

  variables {
    availability_zones = [
      "eu-west-2a",
    ]

    private_subnets = [
      "10.0.1.0/24",
    ]

    public_subnets = [
      "10.0.101.0/24",
    ]
  }

  expect_failures = [
    var.availability_zones,
  ]
}

run "reject_duplicate_availability_zones" {
  command = plan

  variables {
    availability_zones = [
      "eu-west-2a",
      "eu-west-2a",
    ]
  }

  expect_failures = [
    var.availability_zones,
  ]
}

run "reject_private_subnet_count_mismatch" {
  command = plan

  variables {
    private_subnets = [
      "10.0.1.0/24",
    ]
  }

  expect_failures = [
    var.private_subnets,
  ]
}

run "reject_public_subnet_count_mismatch" {
  command = plan

  variables {
    public_subnets = [
      "10.0.101.0/24",
    ]
  }

  expect_failures = [
    var.public_subnets,
  ]
}

run "reject_invalid_vpc_cidr" {
  command = plan

  variables {
    cidr = "not-a-cidr"
  }

  expect_failures = [
    var.cidr,
  ]
}

run "reject_invalid_private_subnet_cidr" {
  command = plan

  variables {
    private_subnets = [
      "10.0.1.0/24",
      "invalid-cidr",
    ]
  }

  expect_failures = [
    var.private_subnets,
  ]
}

run "reject_duplicate_public_subnets" {
  command = plan

  variables {
    public_subnets = [
      "10.0.101.0/24",
      "10.0.101.0/24",
    ]
  }

  expect_failures = [
    var.public_subnets,
  ]
}