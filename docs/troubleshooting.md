# Terraform EKS Troubleshooting Journal

This document records engineering issues encountered while building and hardening the Terraform EKS platform.

The goal is to preserve the debugging process, root causes, fixes, validation steps, and lessons learned rather than documenting only the final working state.

---

# 1. Terraform Module Tests Tried to Use Real AWS Credentials

## Symptom

Running:

```bash
terraform test
```

inside the EKS module failed with:

```text
Error: Invalid provider configuration
```

and:

```text
STS: GetCallerIdentity
InvalidClientTokenId
The security token included in the request is invalid
```

The remaining tests were skipped.

## Cause

The Terraform tests were not fully isolated from the AWS provider and upstream registry module.

Terraform therefore attempted to initialize the real AWS provider and call AWS STS.

## Fix

The tests were changed to use both:

```hcl
mock_provider "aws" {}
```

and:

```hcl
override_module {
  target = module.eks
}
```

The same pattern was used for the VPC module.

This allowed Terraform to:

- mock the AWS provider
- skip real upstream module execution
- evaluate wrapper-module input validation
- run without AWS credentials
- make no AWS API calls

## Validation

EKS module:

```text
Success! 8 passed, 0 failed.
```

Network module:

```text
Success! 7 passed, 0 failed.
```

## Lesson

Terraform unit tests should isolate cloud dependencies when the goal is to test module contracts and validation logic.

---

# 2. Terraform Module Provider Requirements Were Implicit

## Symptom

Reusable modules did not explicitly declare their AWS provider requirements.

Terraform inferred provider requirements from downstream modules.

## Risk

Implicit provider requirements make reusable modules less predictable and can allow incompatible provider versions to be selected.

## Fix

Added explicit provider requirements.

Example:

```hcl
terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.79.0, < 6.0"
    }
  }
}
```

## Validation

```bash
terraform init -backend=false
terraform validate
terraform test
```

All validation and tests passed.

## Lesson

Reusable Terraform modules should explicitly declare their provider requirements.

---

# 3. Module-Level Terraform Lock Files Appeared During Testing

## Symptom

Running:

```bash
terraform init -backend=false
```

inside:

```text
modules/eks
modules/network
```

created:

```text
modules/eks/.terraform.lock.hcl
modules/network/.terraform.lock.hcl
```

They appeared as untracked Git files.

## Cause

Terraform creates a dependency lock file whenever a directory is initialized as a root module.

The reusable modules were temporarily initialized directly for local testing.

## Fix

Removed the generated lock files:

```bash
rm -f modules/eks/.terraform.lock.hcl
rm -f modules/network/.terraform.lock.hcl
```

Added this to `.gitignore`:

```gitignore
modules/**/.terraform.lock.hcl
```

The real root configurations continue to keep committed lock files:

```text
bootstrap/.terraform.lock.hcl
environments/dev/.terraform.lock.hcl
```

## Lesson

Dependency lock files should normally be committed for Terraform root modules.

Reusable child modules generally should not maintain their own lock files.

---

# 4. Terraform Test Directory Did Not Exist

## Symptom

Creating the network test file failed with:

```text
touch: modules/network/tests/guardrails.tftest.hcl:
No such file or directory
```

## Cause

The parent `tests` directory did not yet exist.

## Fix

Created the directory first:

```bash
mkdir -p modules/network/tests
```

Then created the file:

```bash
touch modules/network/tests/guardrails.tftest.hcl
```

## Lesson

`touch` creates files but does not create missing parent directories.

Use `mkdir -p` first when introducing new directory structures.

---

# 5. Command Was Run From the Wrong Working Directory

## Symptom

While already inside:

```text
modules/eks
```

the following command was run:

```bash
cd modules/eks
```

which failed with:

```text
cd: no such file or directory: modules/eks
```

## Cause

The command assumed execution from the repository root.

The shell was already inside the target directory.

## Fix

Confirm the current location:

```bash
pwd
```

Useful navigation commands:

```bash
cd ../network
```

or:

```bash
cd ../..
```

To locate the repository root:

```bash
git rev-parse --show-toplevel
```

## Lesson

When relative paths behave unexpectedly, confirm the current working directory before continuing.

---

# 6. Terraform Displayed an Invalid AWS Token Error

## Symptom

Local Terraform commands displayed:

```text
InvalidClientTokenId
The security token included in the request is invalid
```

while configuration validation later reported:

```text
Success! The configuration is valid.
```

## Cause

The local shell contained stale or invalid AWS temporary credentials.

Environment variables can override credentials from a named AWS profile.

## Fix

Inspect active AWS variables:

```bash
env | grep '^AWS_' || true
```

Clear stale temporary credentials:

```bash
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN
unset AWS_SECURITY_TOKEN
unset AWS_ROLE_ARN
unset AWS_WEB_IDENTITY_TOKEN_FILE
```

Then verify the intended profile explicitly:

```bash
aws sts get-caller-identity \
  --profile one-piece-new
```

## Lesson

Local AWS environment variables can override configured profiles.

Always inspect credential sources when authentication behavior is unexpected.

---

# 7. GitHub Actions OIDC Replaced Long-Lived AWS Credentials

## Goal

Allow GitHub Actions to run Terraform plans against AWS without storing long-lived AWS keys in GitHub.

## Approach

Created an AWS IAM role trusted by:

```text
token.actions.githubusercontent.com
```

The trust relationship is restricted to:

```text
repo:AZ1600/platform-engineering-terraform-eks:ref:refs/heads/main
```

The GitHub workflow requests:

```yaml
permissions:
  contents: read
  id-token: write
```

and assumes the AWS role using:

```text
aws-actions/configure-aws-credentials
```

## Security Benefit

The repository does not require GitHub secrets containing:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_SESSION_TOKEN
```

GitHub receives short-lived AWS credentials for each workflow execution instead.

## Lesson

OIDC federation is preferable to storing long-lived cloud credentials in CI systems.

---

# 8. Terraform Plan Workflow Is Intentionally Plan-Only

## Goal

Allow AWS-backed Terraform validation without accidentally provisioning infrastructure.

## Controls

The workflow:

- uses `workflow_dispatch`
- requires explicit confirmation
- runs only from `main`
- performs `terraform plan`
- contains no `terraform apply`
- does not upload the plan as an artifact
- removes the local plan file afterwards
- prevents overlapping dev plans with concurrency controls

## Reason

The project needs evidence that the Terraform configuration can be planned against AWS without leaving EKS resources running and creating unnecessary cost.

Terraform plan files can also contain infrastructure details and should not automatically be published as artifacts.

## Lesson

Terraform planning and infrastructure deployment should be treated as separate security boundaries.

---

# 9. S3 State Bucket Encryption Lookup Returned AccessDenied

## Symptom

The command:

```bash
aws s3api get-bucket-encryption \
  --bucket "$TF_STATE_BUCKET"
```

returned:

```text
AccessDenied
```

## Investigation

Before diagnosing IAM permissions, inspect the variable:

```bash
echo "$TF_STATE_BUCKET"
```

A placeholder such as:

```text
YOUR_BUCKET_NAME
```

must be replaced with the actual Terraform state bucket.

List available S3 buckets:

```bash
aws s3api list-buckets \
  --profile one-piece-new \
  --query 'Buckets[].Name' \
  --output table
```

Then set the real bucket name:

```bash
TF_STATE_BUCKET="<actual-state-bucket-name>"
```

Retry:

```bash
aws s3api get-bucket-encryption \
  --profile one-piece-new \
  --bucket "$TF_STATE_BUCKET"
```

If the bucket is correct and access is still denied, inspect the IAM permissions of the active AWS identity.

## Lesson

Always verify input variables before assuming an `AccessDenied` response is caused by IAM.

---

# 10. Terraform Guardrails Added for Unsafe EKS Configuration

## Goal

Prevent unsafe or inconsistent infrastructure configuration before Terraform reaches AWS.

## EKS Guardrails

Tests now reject:

```text
Public EKS API access without restricted CIDRs
0.0.0.0/0 public API exposure
::/0 public API exposure
Desired node count below minimum
Desired node count above maximum
Negative minimum node count
Empty node instance type list
Invalid EKS control plane log types
```

## Validation

```text
Success! 8 passed, 0 failed.
```

## Lesson

Configuration safety should be enforced at module boundaries rather than relying only on code review.

---

# 11. Terraform Guardrails Added for Network Topology

## Goal

Prevent invalid or fragile VPC topology from being passed into the network module.

## Network Guardrails

Tests now reject:

```text
Single availability zone topology
Duplicate availability zones
Private subnet count mismatch
Public subnet count mismatch
Invalid VPC CIDR
Invalid private subnet CIDR
Duplicate public subnet CIDRs
```

## Validation

```text
Success! 7 passed, 0 failed.
```

## Lesson

Infrastructure modules should validate architectural assumptions explicitly.

---

# Troubleshooting Checklist

## Git

```bash
git status --short
git diff --check
git diff --stat
```

## Terraform

```bash
terraform version
terraform fmt -check -recursive
```

Validate the dev environment:

```bash
cd environments/dev
terraform init -backend=false
terraform validate
cd ../..
```

## Terraform Tests

EKS:

```bash
cd modules/eks
terraform init -backend=false
terraform test
```

Network:

```bash
cd ../network
terraform init -backend=false
terraform test
```

Return to the repository root:

```bash
cd ../..
```

## AWS Credentials

```bash
env | grep '^AWS_' || true
```

Verify intended profile:

```bash
aws sts get-caller-identity \
  --profile one-piece-new
```

## Terraform Generated Files

```bash
find . \
  \( -name ".terraform" -o -name ".terraform.lock.hcl" \) \
  -print
```

---

# Engineering Principles Reinforced

The issues encountered in this project reinforced several platform engineering practices:

1. isolate infrastructure unit tests from real cloud APIs
2. validate unsafe configuration as early as possible
3. explicitly declare provider requirements
4. distinguish Terraform root modules from reusable child modules
5. use short-lived OIDC credentials in CI
6. separate plan permissions from deployment permissions
7. avoid unnecessary cloud resource creation during CI
8. verify environment variables before debugging IAM
9. validate every fix with repeatable commands
10. document failures as carefully as successful implementations