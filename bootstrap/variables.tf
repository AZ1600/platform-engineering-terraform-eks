variable "aws_region" {
  description = "AWS region used for the Terraform state infrastructure"
  type        = string
  default     = "eu-west-2"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform remote state"
  type        = string
}