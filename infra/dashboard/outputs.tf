output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_client_id" {
  value = aws_cognito_user_pool_client.spa.id
}

output "cognito_domain" {
  value = "${aws_cognito_user_pool_domain.main.domain}.auth.${var.region}.amazoncognito.com"
}

output "cognito_hosted_ui_login_url" {
  value = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.region}.amazoncognito.com/login?client_id=${aws_cognito_user_pool_client.spa.id}&response_type=code&scope=openid+email+profile&redirect_uri=${var.local_dev_url}"
}

output "api_base_url" {
  value = aws_apigatewayv2_api.http.api_endpoint
}

# One block to paste into frontend/.env.local.
# VITE_REDIRECT_URL points at localhost because S3 + CloudFront hosting
# was disabled by this Learner Lab's SCP (see hosting.tf for details).
output "frontend_env_block" {
  value = <<EOT
VITE_AWS_REGION=${var.region}
VITE_COGNITO_USER_POOL_ID=${aws_cognito_user_pool.main.id}
VITE_COGNITO_APP_CLIENT_ID=${aws_cognito_user_pool_client.spa.id}
VITE_COGNITO_DOMAIN=${aws_cognito_user_pool_domain.main.domain}.auth.${var.region}.amazoncognito.com
VITE_API_BASE_URL=${aws_apigatewayv2_api.http.api_endpoint}
VITE_REDIRECT_URL=${var.local_dev_url}
EOT
}
