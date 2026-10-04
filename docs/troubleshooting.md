# Terraform EKS Troubleshooting Journal

This document records engineering issues encountered while building, testing, securing, and automating the Terraform EKS platform.

The goal is to preserve the debugging process, root causes, fixes, validation steps, and lessons learned rather than documenting only the final working configuration.

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

Terraform therefore attempted to initialize the real AWS provider and contact AWS STS.

## Initial Attempt

The test initially used:

```hcl
mock_provider "aws" {}
```

but the upstream module was still involved in the plan.

A later attempt used only:

```hcl
override_module {
  target = module.eks
}
```

but Terraform still expected provider configuration.

## Fix

The working solution combined both mechanisms:

```hcl
mock_provider "aws" {}
```

and:

```hcl
override_module {
  target = module.eks

  outputs = {
    cluster_name     = "platform-test"
    cluster_endpoint = "https://example.invalid"
  }
}
```

The network module uses the same pattern for:

```hcl
module.vpc
```

This allowed Terraform to:

- mock AWS
- avoid real API calls
- bypass the upstream registry module implementation
- evaluate the wrapper module
- test input guardrails
- run without AWS credentials

## Validation

EKS:

```text
Success! 8 passed, 0 failed.
```

Network:

```text
Success! 7 passed, 0 failed.
```

## Lesson

For wrapper-module unit tests, mocking the provider and overriding external child modules can keep tests deterministic and independent from cloud APIs.

---

# 2. Reusable Terraform Modules Had Implicit Provider Requirements

## Symptom

The reusable EKS and network modules did not explicitly declare their AWS provider requirements.

Terraform inferred provider dependencies through their child modules.

## Risk

Implicit provider requirements can make reusable modules less predictable and may allow incompatible provider versions.

## Fix

Added explicit requirements to:

```text
modules/eks/versions.tf
modules/network/versions.tf
```

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

All module tests passed.

## Lesson

Reusable Terraform modules should explicitly declare the providers and version ranges they support.

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

They appeared as untracked files.

## Cause

Terraform treats the current working directory as a root module during direct initialization and creates a dependency lock file.

The directories are reusable child modules in this repository, not normal deployment roots.

## Fix

Removed the generated files:

```bash
rm -f modules/eks/.terraform.lock.hcl
rm -f modules/network/.terraform.lock.hcl
```

Added this ignore rule:

```gitignore
modules/**/.terraform.lock.hcl
```

The real Terraform root configurations continue to keep their committed lock files:

```text
bootstrap/.terraform.lock.hcl
environments/dev/.terraform.lock.hcl
```

## Lesson

Commit lock files for Terraform root configurations.

Do not normally maintain generated lock files inside reusable child modules.

---

# 4. Terraform Test Directory Did Not Exist

## Symptom

Creating:

```text
modules/network/tests/guardrails.tftest.hcl
```

failed with:

```text
No such file or directory
```

## Cause

The parent directory had not yet been created.

## Fix

Created the directory first:

```bash
mkdir -p modules/network/tests
```

Then created the file:

```bash
touch modules/network/tests/guardrails.tftest.hcl
```

The same structure is used for EKS:

```text
modules/eks/tests/guardrails.tftest.hcl
```

## Lesson

`touch` creates a file but does not create missing parent directories.

Use:

```bash
mkdir -p
```

when introducing a new directory structure.

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

and failed with:

```text
cd: no such file or directory: modules/eks
```

## Cause

The command assumed execution from the repository root.

## Fix

Check the current location:

```bash
pwd
```

Find the repository root:

```bash
git rev-parse --show-toplevel
```

Navigate from the current directory instead:

```bash
cd ../network
```

or:

```bash
cd ../..
```

## Lesson

When relative paths behave unexpectedly, verify the shell's current working directory before troubleshooting anything else.

---

# 6. Local Terraform Commands Encountered an Invalid AWS Token

## Symptom

Terraform initialization displayed:

```text
InvalidClientTokenId
The security token included in the request is invalid
```

while Terraform configuration validation still reported:

```text
Success! The configuration is valid.
```

## Cause

The shell contained stale or invalid temporary AWS environment credentials.

Environment variables can take precedence over credentials from an AWS CLI profile.

## Investigation

Inspect AWS-related variables:

```bash
env | grep '^AWS_' || true
```

## Fix

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

When AWS authentication behaves unexpectedly, inspect all credential sources before assuming Terraform or IAM is broken.

---

# 7. EKS Guardrails Were Added to Prevent Unsafe Configuration

## Goal

Reject unsafe or internally inconsistent EKS configuration before Terraform reaches AWS.

## Guardrails

The module tests reject:

```text
Public EKS API without restricted CIDRs
0.0.0.0/0 public endpoint access
::/0 public endpoint access
Desired nodes below minimum
Desired nodes above maximum
Negative minimum node count
Empty node instance type list
Invalid control plane log types
```

Worker disk sizing is also validated.

## Validation

```text
Success! 8 passed, 0 failed.
```

## Lesson

Security and operational invariants are stronger when enforced directly at module boundaries rather than relying only on code review.

---

# 8. Network Guardrails Were Added to Protect Topology

## Goal

Prevent structurally invalid VPC configuration.

## Guardrails

The network module tests reject:

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

Infrastructure modules should encode architectural assumptions as validations and tests.

---

# 9. GitHub Actions OIDC Was Introduced Instead of Long-Lived AWS Keys

## Goal

Allow GitHub Actions to authenticate to AWS without storing static AWS credentials.

## Architecture

```text
GitHub Actions
      |
      v
GitHub OIDC Token
      |
      v
AWS STS AssumeRoleWithWebIdentity
      |
      v
GitHubTerraformPlanRole
      |
      v
Temporary AWS Credentials
```

## GitHub Permissions

The workflow requests:

```yaml
permissions:
  contents: read
  id-token: write
```

AWS credentials are configured using:

```text
aws-actions/configure-aws-credentials
```

## IAM Trust Restriction

The trust policy restricts access to:

```text
repo:AZ1600/platform-engineering-terraform-eks:ref:refs/heads/main
```

## Security Benefit

GitHub does not need secrets containing:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_SESSION_TOKEN
```

## Lesson

OIDC federation provides short-lived credentials and avoids the operational risk of long-lived CI access keys.

---

# 10. Terraform Plan Workflow Was Deliberately Kept Plan-Only

## Goal

Validate the real AWS infrastructure plan without automatically creating resources.

## Controls

The workflow:

- uses `workflow_dispatch`
- requires explicit confirmation
- runs only from `main`
- authenticates through OIDC
- verifies AWS identity
- initializes real remote state
- runs `terraform validate`
- runs `terraform plan`
- handles detailed exit codes
- does not contain `terraform apply`
- does not upload the plan file
- removes the plan file afterwards
- prevents overlapping dev plan runs

## Reason

Amazon EKS, NAT Gateway, worker nodes, and related services can create ongoing cost.

The project needs strong evidence that the infrastructure can be planned successfully without requiring a permanently running environment.

## Lesson

Terraform plan and Terraform apply should be treated as different security boundaries.

---

# 11. State Bucket Variable Was Initially Left as a Placeholder

## Symptom

A state encryption lookup failed after:

```bash
TF_STATE_BUCKET="YOUR_BUCKET_NAME"
```

was still present.

## Cause

The placeholder had not yet been replaced by the actual state bucket.

## Investigation

List S3 buckets:

```bash
aws s3api list-buckets \
  --profile one-piece-new \
  --query 'Buckets[].Name' \
  --output table
```

The project state bucket was identified as:

```text
az1600-platform-eks-tfstate-8caa64f5
```

## Fix

Set the real value:

```bash
TF_STATE_BUCKET="az1600-platform-eks-tfstate-8caa64f5"
```

## Lesson

Before diagnosing IAM permissions, verify that resource names and shell variables contain real values rather than placeholders.

---

# 12. Existing State Bucket Uses SSE-S3 Rather Than the Current KMS Target Design

## Symptom

Inspecting the state bucket encryption returned:

```json
{
  "SSEAlgorithm": "AES256"
}
```

The project had expected a customer-managed KMS key.

## Investigation

The bucket was inspected with:

```bash
aws s3api get-bucket-encryption \
  --profile "$AWS_PROFILE" \
  --bucket "$TF_STATE_BUCKET"
```

The live bucket reported:

```text
SSE-S3
AES256
```

## Cause

The existing state bucket reflects an earlier infrastructure baseline.

The current `bootstrap/` Terraform configuration now defines a stronger KMS-backed state design.

Therefore:

```text
Existing live state bucket
!=
Current bootstrap target configuration
```

## Impact

The current bucket remains server-side encrypted, but it is not yet aligned with the customer-managed KMS configuration now defined in Terraform.

## Decision

The difference is documented transparently rather than presenting the historical bucket as identical to the current bootstrap configuration.

A future migration or bootstrap rebuild can bring the live state foundation into alignment.

## Lesson

Infrastructure documentation should distinguish between:

```text
current IaC target state
```

and:

```text
historical live infrastructure
```

when they are not identical.

---

# 13. KMS Key Lookup Returned `None`

## Symptom

The following command returned:

```text
None
```

for the KMS key:

```bash
KMS_KEY_ARN="$(
  aws s3api get-bucket-encryption \
    --profile "$AWS_PROFILE" \
    --bucket "$TF_STATE_BUCKET" \
    --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.KMSMasterKeyID' \
    --output text
)"
```

## Cause

The bucket uses:

```text
AES256
```

rather than:

```text
aws:kms
```

SSE-S3 does not have a customer-managed KMS key ARN.

## Fix

Removed unnecessary KMS permissions from the GitHub Terraform plan role's state-access policy.

The workflow only needed:

```text
s3:ListBucket
s3:GetObject
s3:PutObject
s3:DeleteObject
```

for the relevant state and lock paths.

## Lesson

Do not add permissions for services or keys that the actual runtime infrastructure does not use.

Inspect the real resource first, then build the least-privilege policy around it.

---

# 14. Terraform Plan Role Needed State Lock Write Permissions

## Goal

Keep the GitHub role read-only for infrastructure while still allowing normal Terraform state coordination.

## Challenge

A Terraform plan using:

```hcl
use_lockfile = true
```

may need to create and delete an S3 lock object.

Pure infrastructure read-only access is therefore not enough for remote-state locking.

## Solution

The IAM model separates infrastructure permissions from state permissions.

Conceptually:

```text
AWS infrastructure
    |
    └── Read only

Terraform state
    |
    └── Read

Terraform lock object
    |
    ├── Read
    ├── Create
    └── Delete
```

The lock path is scoped to:

```text
eks/dev/terraform.tfstate.tflock
```

## Lesson

"Plan-only" does not necessarily mean every API permission is read-only.

Terraform may require narrowly scoped write permissions for state locking even when no infrastructure mutation is allowed.

---

# 15. GitHub Repository Variables Were Used for Non-Secret Configuration

## Configuration

The workflow uses GitHub repository variables for:

```text
AWS_TERRAFORM_PLAN_ROLE_ARN
TF_STATE_BUCKET
```

They were configured with:

```bash
gh variable set
```

## Reason

These values are configuration rather than credentials.

No AWS access keys are stored in GitHub.

## Lesson

Use secrets only for secret values.

Non-sensitive infrastructure identifiers can remain repository variables.

---

# 16. Terminal Paste Introduced a `[200~` Prefix

## Symptom

A pasted Git command became:

```text
[200~git push -u origin ci/github-oidc-terraform-plan
```

and zsh returned:

```text
zsh: bad pattern: [200~git
```

## Cause

A terminal bracketed-paste control sequence was inserted into the command text.

The actual Git branch and commit were fine.

## Fix

Retyped the command manually:

```bash
git push -u origin ci/github-oidc-terraform-plan
```

The push succeeded.

## Lesson

When a normal command suddenly contains characters such as:

```text
[200~
```

the problem may be terminal paste handling rather than the command itself.

Retype the command before debugging Git or the shell configuration.

---

# 17. GitHub OIDC Terraform Plan Completed Successfully

## Goal

Prove the complete plan path using real AWS authentication and real remote state.

## Workflow

The manually triggered run executed:

```text
Checkout repository
Setup Terraform
Configure AWS credentials with GitHub OIDC
Verify AWS identity
Initialize Terraform remote state
Validate Terraform
Create Terraform plan
Show Terraform plan
Write job summary
Remove local plan file
```

All steps completed successfully.

## Validated Path

```text
GitHub Actions
      |
      v
GitHub OIDC
      |
      v
AWS IAM Role
      |
      v
AWS STS Temporary Credentials
      |
      v
S3 Terraform Remote State
      |
      v
terraform validate
      |
      v
terraform plan
      |
      v
Success
```

## Result

```text
Terraform dev plan
Completed with success
```

The workflow completed without:

```text
terraform apply
```

and therefore created no infrastructure.

## What This Proved

The successful run demonstrated that:

- GitHub could request an OIDC token
- AWS trusted the repository and branch
- the IAM role could be assumed
- AWS identity verification worked
- the real S3 backend could be initialized
- state locking worked
- Terraform validation succeeded
- Terraform planning succeeded
- the plan file was cleaned up
- no long-lived AWS credentials were needed
- no infrastructure was applied

## Lesson

A real plan-only cloud workflow provides stronger portfolio evidence than syntax validation alone while still preserving cost and deployment safety.

---

# 18. GitHub Actions Reported a Node.js 20 Deprecation Annotation

## Symptom

The successful GitHub Actions run displayed a warning similar to:

```text
Node.js 20 is deprecated.
The following actions target Node.js 20 but are being forced to run on Node.js 24.
```

The notice referenced actions including:

```text
actions/checkout
aws-actions/configure-aws-credentials
hashicorp/setup-terraform
```

## Impact

The workflow still completed successfully.

This was a GitHub runner compatibility/deprecation annotation, not a Terraform or AWS failure.

## Decision

No immediate repository change was required because the workflow remained functional.

Action versions should be reviewed periodically and upgraded when their maintainers publish versions targeting the newer runtime.

## Lesson

CI warnings should be distinguished from actual workflow failures.

They are still worth recording because platform runtimes evolve even when project code remains unchanged.

---

# 19. GitHub Reported an Upcoming `ubuntu-latest` Runner Migration

## Symptom

GitHub Actions also displayed an annotation indicating that the:

```text
ubuntu-latest
```

label would migrate to a newer Ubuntu release.

## Impact

The Terraform workflow still completed successfully.

## Consideration

Infrastructure CI should periodically be tested against updated runner images because changes can affect:

- preinstalled packages
- shell behavior
- cloud CLIs
- Docker
- system libraries

## Lesson

Hosted CI runners are external dependencies and should be treated like any other changing platform component.

---

# 20. Documentation Was Updated After Engineering Changes

## Problem

The README originally described several capabilities as future improvements even though they already existed.

Examples included:

```text
TFLint
IaC security scanning
```

Later engineering work also added:

```text
terraform test
GitHub OIDC
AWS-backed Terraform plan
troubleshooting documentation
```

## Fix

The README was refreshed after completing the engineering work rather than trying to update documentation after every small intermediate change.

## Lesson

Documentation should reflect the final verified implementation, not an outdated roadmap.

---

# Troubleshooting Checklist

## Confirm Repository Location

```bash
pwd
git rev-parse --show-toplevel
```

---

## Git Status

```bash
git status --short
git diff --check
git diff --stat
```

---

## Terraform Formatting

```bash
terraform fmt -check -recursive
```

---

## Validate Bootstrap

```bash
cd bootstrap

terraform init -backend=false
terraform validate
```

---

## Validate Dev Environment

```bash
cd environments/dev

terraform init -backend=false
terraform validate
```

---

## Run EKS Tests

```bash
cd modules/eks

terraform init -backend=false
terraform test
```

Expected:

```text
Success! 8 passed, 0 failed.
```

---

## Run Network Tests

```bash
cd modules/network

terraform init -backend=false
terraform test
```

Expected:

```text
Success! 7 passed, 0 failed.
```

---

## Return to Repository Root

```bash
cd ../..
```

---

## Inspect AWS Credential Environment

```bash
env | grep '^AWS_' || true
```

---

## Clear Stale AWS Temporary Credentials

```bash
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN
unset AWS_SECURITY_TOKEN
unset AWS_ROLE_ARN
unset AWS_WEB_IDENTITY_TOKEN_FILE
```

---

## Verify Local AWS Identity

```bash
aws sts get-caller-identity \
  --profile one-piece-new
```

---

## List S3 Buckets

```bash
aws s3api list-buckets \
  --profile one-piece-new \
  --query 'Buckets[].Name' \
  --output table
```

---

## Inspect State Bucket Encryption

```bash
aws s3api get-bucket-encryption \
  --profile one-piece-new \
  --bucket "$TF_STATE_BUCKET"
```

---

## List GitHub Repository Variables

```bash
gh variable list \
  --repo AZ1600/platform-engineering-terraform-eks
```

---

## Run GitHub OIDC Terraform Plan

```bash
gh workflow run terraform-plan.yml \
  --repo AZ1600/platform-engineering-terraform-eks \
  --ref main \
  -f confirm_plan=true
```

---

## Watch Workflow

```bash
gh run watch \
  --repo AZ1600/platform-engineering-terraform-eks
```

---

## Inspect Failed Workflow Logs

```bash
gh run view <RUN_ID> \
  --repo AZ1600/platform-engineering-terraform-eks \
  --log-failed
```

---

## Inspect Terraform-Generated Files

```bash
find . \
  \( -name ".terraform" -o -name ".terraform.lock.hcl" \) \
  -print
```

---

# Engineering Principles Reinforced

The work on this repository reinforced several platform engineering practices:

1. isolate infrastructure unit tests from real cloud APIs
2. encode security assumptions as Terraform validations
3. test failure cases, not only valid configurations
4. explicitly declare reusable module provider requirements
5. distinguish root modules from reusable child modules
6. commit dependency locks for deployment roots
7. use short-lived OIDC credentials in CI
8. avoid long-lived cloud access keys
9. restrict OIDC trust to the intended repository and branch
10. separate Terraform plan permissions from apply permissions
11. scope state-lock writes narrowly
12. inspect live infrastructure before designing IAM permissions
13. distinguish historical infrastructure from the current IaC target
14. verify environment variables before debugging IAM
15. avoid unnecessary cloud resource creation for portfolio evidence
16. treat CI runner platforms and actions as evolving dependencies
17. validate every fix with repeatable commands
18. preserve failed approaches as engineering knowledge
19. document operational differences transparently
20. treat troubleshooting as part of the engineering deliverable