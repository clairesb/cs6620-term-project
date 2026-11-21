# API Gateway (HTTP API) — the public front door of the dashboard.
# Every browser request hits here first. The Cognito JWT authorizer
# below rejects requests that do not carry a valid token issued by
# our User Pool; valid requests are forwarded to the stub Lambda.
# Access logs land in CloudWatch for audit + demo evidence.

resource "aws_apigatewayv2_api" "http" {
  name          = "${local.name_prefix}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["http://localhost:5173"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Authorization", "Content-Type"]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.http.id
  name             = "cognito-jwt"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
    # The issuer field tells the authorizer "trust only JWTs issued by my Cognito pool."
    # The audience field pins it to my app client — so a JWT from someone else's Cognito pool,
    # or even a different app in the same pool, cannot access my API.
  jwt_configuration {
    issuer   = "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.main.id}"
    audience = [aws_cognito_user_pool_client.spa.id]
  }
}

resource "aws_apigatewayv2_integration" "stub" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.stub_api.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

locals {
  protected_routes = [
    "GET /scans",
    "GET /scans/{scanId}/findings/{findingId}",
    "POST /scans/{scanId}/export",
  ]
}

resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.stub.id}"
}

resource "aws_apigatewayv2_route" "protected" {
  for_each           = toset(local.protected_routes)
  api_id             = aws_apigatewayv2_api.http.id
  route_key          = each.value
  target             = "integrations/${aws_apigatewayv2_integration.stub.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
  authorization_type = "JWT"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
      authError      = "$context.authorizer.error"
    })
  }
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name              = "/aws/apigw/${local.name_prefix}"
  retention_in_days = 7
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stub_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}
