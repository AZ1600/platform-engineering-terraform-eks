variable "cluster_name" {
  description = "Amazon EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for Amazon EKS"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID used by the EKS cluster"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs used by the EKS cluster"
  type        = list(string)
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "node_instance_types" {
  description = "EC2 instance types used by the managed node group"
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

variable "tags" {
  description = "Tags applied to EKS resources"
  type        = map(string)
}

variable "cluster_endpoint_private_access" {
  description = "Enable private access to the Amazon EKS API endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Enable public access to the Amazon EKS API endpoint"
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to access the public Amazon EKS API endpoint"
  type        = list(string)
  default     = []
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Grant the Terraform cluster creator administrator access"
  type        = bool
  default     = false
}

variable "cluster_admin_principal_arn" {
  description = "Optional IAM principal granted explicit Amazon EKS cluster administrator access"
  type        = string
  default     = null
}

variable "node_disk_size" {
  description = "Encrypted root disk size in GiB for EKS managed nodes"
  type        = number
  default     = 30

  validation {
    condition     = var.node_disk_size >= 20
    error_message = "EKS node disk size must be at least 20 GiB."
  }
}

variable "cluster_enabled_log_types" {
  description = "Amazon EKS control plane log types sent to CloudWatch"
  type        = list(string)

  default = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]
}