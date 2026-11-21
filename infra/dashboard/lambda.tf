# Stub Lambda — stands in for Member 2's real scan-orchestrator Lambda.
# Returns hard-coded SAST + Pentest scan results so the full
# browser -> Cognito -> API Gateway -> Lambda path can be demoed
# without blocking on teammate work. Execution role is the pre-existing
# Learner Lab "LabRole" because Learner Lab forbids creating IAM roles.

data "archive_file" "stub_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/stub-lambda"
  output_path = "${path.module}/.build/stub-lambda.zip"
}

resource "aws_cloudwatch_log_group" "stub_lambda" {
  name              = "/aws/lambda/${local.name_prefix}-stub-api"
  retention_in_days = 7
}

resource "aws_lambda_function" "stub_api" {
  function_name = "${local.name_prefix}-stub-api"
  role          = var.lambda_execution_role_arn
  runtime       = "nodejs20.x"
  handler       = "index.handler"

  filename         = data.archive_file.stub_lambda.output_path
  source_code_hash = data.archive_file.stub_lambda.output_base64sha256

  timeout     = 10
  memory_size = 128

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.stub_lambda.name
  }
}
