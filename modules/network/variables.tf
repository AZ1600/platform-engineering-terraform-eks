variable "name" {
  description = "Name of the VPC"
  type        = string

  validation {
    condition     = length(trimspace(var.name)) > 0
    error_message = "VPC name must not be empty."
  }
}

variable "cidr" {
  description = "CIDR block for the VPC"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.cidr))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "Availability zones used by the VPC"
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least two availability zones are required."
  }

  validation {
    condition     = length(distinct(var.availability_zones)) == length(var.availability_zones)
    error_message = "Availability zones must not contain duplicates."
  }
}

variable "private_subnets" {
  description = "Private subnet CIDR blocks"
  type        = list(string)

  validation {
    condition     = length(var.private_subnets) == length(var.availability_zones)
    error_message = "The number of private subnets must match the number of availability zones."
  }

  validation {
    condition = alltrue([
      for cidr in var.private_subnets :
      can(cidrnetmask(cidr))
    ])

    error_message = "Every private subnet must use a valid IPv4 CIDR block."
  }

  validation {
    condition     = length(distinct(var.private_subnets)) == length(var.private_subnets)
    error_message = "Private subnet CIDR blocks must not contain duplicates."
  }
}

variable "public_subnets" {
  description = "Public subnet CIDR blocks"
  type        = list(string)

  validation {
    condition     = length(var.public_subnets) == length(var.availability_zones)
    error_message = "The number of public subnets must match the number of availability zones."
  }

  validation {
    condition = alltrue([
      for cidr in var.public_subnets :
      can(cidrnetmask(cidr))
    ])

    error_message = "Every public subnet must use a valid IPv4 CIDR block."
  }

  validation {
    condition     = length(distinct(var.public_subnets)) == length(var.public_subnets)
    error_message = "Public subnet CIDR blocks must not contain duplicates."
  }
}

variable "tags" {
  description = "Tags applied to network resources"
  type        = map(string)
}