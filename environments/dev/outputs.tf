output "environment" {
  description = "Deployment environment"
  value       = var.environment
}

output "cluster_name" {
  description = "Amazon EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_version" {
  description = "Kubernetes version configured for Amazon EKS"
  value       = var.cluster_version
}

output "cluster_endpoint" {
  description = "Amazon EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "vpc_id" {
  description = "VPC ID used by the platform"
  value       = module.network.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by Amazon EKS"
  value       = module.network.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs created for the environment"
  value       = module.network.public_subnet_ids
}