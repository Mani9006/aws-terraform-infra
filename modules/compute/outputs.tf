# ---------------------------------------------------------------------------
# Compute Module - Outputs
# ---------------------------------------------------------------------------
# Exposes key resource identifiers and endpoints for other modules and
# the root configuration to consume.
# ---------------------------------------------------------------------------

output "launch_template_id" {
  description = "ID of the created launch template."
  value       = aws_launch_template.app.id
}

output "launch_template_arn" {
  description = "ARN of the created launch template."
  value       = aws_launch_template.app.arn
}

output "launch_template_latest_version" {
  description = "Latest version number of the launch template."
  value       = aws_launch_template.app.latest_version
}

output "autoscaling_group_id" {
  description = "ID of the auto scaling group."
  value       = aws_autoscaling_group.app.id
}

output "autoscaling_group_name" {
  description = "Name of the auto scaling group."
  value       = aws_autoscaling_group.app.name
}

output "autoscaling_group_arn" {
  description = "ARN of the auto scaling group."
  value       = aws_autoscaling_group.app.arn
}

output "alb_arn" {
  description = "ARN of the application load balancer. Null if disabled."
  value       = var.enable_load_balancer ? aws_lb.app[0].arn : null
}

output "alb_dns_name" {
  description = "DNS name of the application load balancer. Null if disabled."
  value       = var.enable_load_balancer ? aws_lb.app[0].dns_name : null
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the ALB for Route53 alias records."
  value       = var.enable_load_balancer ? aws_lb.app[0].zone_id : null
}

output "target_group_arn" {
  description = "ARN of the ALB target group. Null if disabled."
  value       = var.enable_load_balancer ? aws_lb_target_group.app[0].arn : null
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the target group for CloudWatch metric dimensions."
  value       = var.enable_load_balancer ? aws_lb_target_group.app[0].arn_suffix : null
}

output "security_group_ec2_id" {
  description = "ID of the EC2 security group."
  value       = aws_security_group.ec2.id
}

output "security_group_alb_id" {
  description = "ID of the ALB security group. Null if ALB is disabled."
  value       = var.enable_load_balancer ? aws_security_group.alb[0].id : null
}

output "iam_role_arn" {
  description = "ARN of the IAM role assigned to EC2 instances."
  value       = var.iam_instance_profile == "" ? aws_iam_role.ec2[0].arn : null
}

output "iam_instance_profile_name" {
  description = "Name of the IAM instance profile used by EC2 instances."
  value       = local.instance_profile_name
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for CloudWatch alarms."
  value       = aws_sns_topic.alarms.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic for CloudWatch alarms."
  value       = aws_sns_topic.alarms.name
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for EC2 instances."
  value       = aws_cloudwatch_log_group.ec2.name
}

output "kms_key_arn_ebs" {
  description = "ARN of the KMS key used for EBS encryption."
  value       = aws_kms_key.ebs[0].arn
}

output "ami_id_used" {
  description = "AMI ID actually used for instances (resolved from data source if not provided)."
  value       = local.ami_id
}
