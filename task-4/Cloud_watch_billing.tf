resource "aws_cloudwatch_metric_alarm" "billing_alarm" {
  alarm_name          = "nimbustech-monthly-budget-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 21600 # 6 hours
  statistic           = "Maximum"
  threshold           = 350
  alarm_description   = "Alert when monthly billing exceeds $350 USD"

  dimensions = {
    Currency = "USD"
  }

  alarm_actions = [aws_sns_topic.billing_alerts.arn]
}

resource "aws_sns_topic" "billing_alerts" {
  name = "billing-alerts-topic"
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.billing_alerts.arn
  protocol  = "email"
  endpoint  = "finance@nimbustech.com" # Replace with actual email
}