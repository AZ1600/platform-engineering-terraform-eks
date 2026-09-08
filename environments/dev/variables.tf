variable "aws_region" {
  description = "AWS region for the platform"
  type        = string
  default     = "eu-west-2"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project identifier used for naming and tagging"
  type        = string
  default     = "platform-engineering"
}

variable "cluster_name" {
  description = "Amazon EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for Amazon EKS"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones used by the VPC"
  type        = list(string)
}

variable "private_subnets" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
}

variable "public_subnets" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
}

variable "node_instance_types" {
  description = "EC2 instance types used by the EKS managed node group"
  type        = list(string)
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
}

variable "cluster_endpoint_public_access" {
  description = "Enable public access to the EKS API endpoint"
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to access the public EKS API endpoint"
  type        = list(string)
  default     = []
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Grant the Terraform cluster creator administrator access"
  type        = bool
  default     = true
}

variable "cluster_admin_principal_arn" {
  description = "Optional IAM principal granted explicit EKS administrator access"
  type        = string
  default     = null
}

variable "node_disk_size" {
  description = "Encrypted EKS worker root volume size in GiB"
  type        = number
  default     = 30
}