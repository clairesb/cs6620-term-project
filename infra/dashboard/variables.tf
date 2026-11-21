variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "cs6620-compliance"
}

variable "env" {
  type    = string
  default = "dev"
}

# Learner Lab forbids creating new IAM roles. Use the pre-existing LabRole for Lambda.
# After `terraform init`, run `aws sts get-caller-identity` and fill the account id into terraform.tfvars.
variable "lambda_execution_role_arn" {
  type        = string
  description = "ARN of the Lambda execution role. In Learner Lab this is arn:aws:iam::<account>:role/LabRole."
}

# Local dev URL + the eventual CloudFront URL get added as callback URLs.
variable "local_dev_url" {
  type    = string
  default = "http://localhost:5173/"
}
