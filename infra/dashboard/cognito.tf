# Cognito User Pool — the identity system for the compliance dashboard.
# Defines who can log in (users), how (password policy, Hosted UI),
# and what role they have (reviewer / operator / admin groups).
# The app client at the bottom is the "registration" the React SPA uses
# to request tokens via the OAuth authorization-code flow.

resource "aws_cognito_user_pool" "main" {
  name = "${local.name_prefix}-users"

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = false
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  auto_verified_attributes = ["email"]

  schema {
    name                = "email"
    attribute_data_type = "String"
    mutable             = true
    required            = true
    string_attribute_constraints {
      min_length = 3
      max_length = 256
    }
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }
}

resource "aws_cognito_user_pool_domain" "main" {
  # Must be globally unique within the region.
  domain       = "${local.name_prefix}-${local.account_id}"
  user_pool_id = aws_cognito_user_pool.main.id
}

resource "aws_cognito_user_group" "reviewer" {
  name         = "reviewer"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Read-only dashboard access"
}

resource "aws_cognito_user_group" "operator" {
  name         = "operator"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Can trigger on-demand scans"
}

resource "aws_cognito_user_group" "admin" {
  name         = "admin"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Can modify schedules + apply legal holds"
}

resource "aws_cognito_user_pool_client" "spa" {
  name            = "${local.name_prefix}-spa"
  user_pool_id    = aws_cognito_user_pool.main.id
  generate_secret = false

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email", "profile"]

  # S3+CloudFront hosting removed — this Learner Lab denies
  # cloudfront:CreateOriginAccessControl and s3:GetBucketObjectLockConfiguration
  # via SCP. Demoing the frontend from localhost instead; see Docs/TODAY_ACTION_PLAN.md.
  callback_urls = [var.local_dev_url]
  logout_urls   = [var.local_dev_url]

  supported_identity_providers  = ["COGNITO"]
  explicit_auth_flows           = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  prevent_user_existence_errors = "ENABLED"
}
