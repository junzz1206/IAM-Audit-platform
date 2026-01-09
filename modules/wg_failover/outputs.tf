output "lambda_name" { value = aws_lambda_function.failover.function_name }
output "alarm_name"  { value = aws_cloudwatch_metric_alarm.active_failed.alarm_name }