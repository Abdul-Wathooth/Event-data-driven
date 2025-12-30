# ---------------------------
# S3 Buckets
# ---------------------------
resource "aws_s3_bucket" "raw" {
  bucket = "event-raw-data-bucket-123"
}

resource "aws_s3_bucket" "processed" {
  bucket = "event-processed-data-bucket-123"
}

resource "aws_s3_bucket" "reports" {
  bucket = "event-daily-reports-bucket-123"
}

# ---------------------------
# ZIP Lambda Code (AUTO)
# ---------------------------
data "archive_file" "processor_zip" {
  type        = "zip"
  source_file = "../lambda/data_processor.py"
  output_path = "../lambda/data_processor.zip"
}

data "archive_file" "report_zip" {
  type        = "zip"
  source_file = "../lambda/report_generator.py"
  output_path = "../lambda/report_generator.zip"
}

# ---------------------------
# Lambda – Data Processor
# ---------------------------
resource "aws_lambda_function" "processor" {
  function_name = "data-processor"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.9"
  handler       = "data_processor.lambda_handler"
  filename      = data.archive_file.processor_zip.output_path

  depends_on = [
    aws_iam_role_policy.lambda_policy
  ]
}

# ---------------------------
# Lambda – Report Generator
# ---------------------------
resource "aws_lambda_function" "report" {
  function_name = "daily-report-generator"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.9"
  handler       = "report_generator.lambda_handler"
  filename      = data.archive_file.report_zip.output_path

  depends_on = [
    aws_iam_role_policy.lambda_policy
  ]
}

# ---------------------------
# Allow S3 to invoke Processor Lambda
# ---------------------------
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw.arn
}

# ---------------------------
# S3 Event Notification
# ---------------------------
resource "aws_s3_bucket_notification" "raw_trigger" {
  bucket = aws_s3_bucket.raw.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [
    aws_lambda_permission.allow_s3
  ]
}

# ---------------------------
# EventBridge Daily Schedule
# ---------------------------
resource "aws_cloudwatch_event_rule" "daily" {
  name                = "daily-report-rule"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "daily_lambda" {
  rule = aws_cloudwatch_event_rule.daily.name
  arn  = aws_lambda_function.report.arn
}

# ---------------------------
# Allow EventBridge to invoke Report Lambda
# ---------------------------
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.report.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily.arn
}
