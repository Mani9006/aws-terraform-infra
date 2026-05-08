# ---------------------------------------------------------------------------
# VPC Module - Outputs
# ---------------------------------------------------------------------------
# These outputs expose critical resource identifiers for use by other
# modules and the root configuration. Marked as sensitive where appropriate.
# ---------------------------------------------------------------------------

output "vpc_id" {
  description = "The ID of the created VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the created VPC."
  value       = aws_vpc.main.cidr_block
}

output "vpc_arn" {
  description = "The ARN of the created VPC."
  value       = aws_vpc.main.arn
}

output "public_subnet_ids" {
  description = "List of public subnet IDs across all AZs. Used for load balancer placement."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs across all AZs. Used for application instance placement."
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "List of database subnet IDs across all AZs. Used for RDS subnet group placement."
  value       = aws_subnet.database[*].id
}

output "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks."
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks."
  value       = aws_subnet.private[*].cidr_block
}

output "database_subnet_cidrs" {
  description = "List of database subnet CIDR blocks."
  value       = aws_subnet.database[*].cidr_block
}

output "nat_gateway_ids" {
  description = "List of NAT gateway IDs. Empty if NAT is disabled."
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_public_ips" {
  description = "List of public Elastic IPs assigned to NAT gateways."
  value       = aws_eip.nat[*].public_ip
}

output "internet_gateway_id" {
  description = "The ID of the internet gateway attached to the VPC."
  value       = aws_internet_gateway.main.id
}

output "public_route_table_id" {
  description = "The ID of the public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "List of private route table IDs, one per AZ."
  value       = aws_route_table.private[*].id
}

output "database_route_table_id" {
  description = "The ID of the database route table."
  value       = aws_route_table.database.id
}

output "availability_zones" {
  description = "The list of availability zones used for subnet placement."
  value       = var.availability_zones
}

output "flow_logs_log_group_arn" {
  description = "ARN of the CloudWatch log group for VPC flow logs."
  value       = var.enable_vpc_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].arn : null
}

output "vpc_endpoint_s3_id" {
  description = "The ID of the S3 VPC endpoint."
  value       = aws_vpc_endpoint.s3.id
}

output "vpc_endpoints_security_group_id" {
  description = "Security group ID for VPC interface endpoints."
  value       = aws_security_group.vpc_endpoints.id
}

output "kms_key_arn_flow_logs" {
  description = "ARN of the KMS key used for flow log encryption."
  value       = var.enable_vpc_flow_logs ? aws_kms_key.flow_logs[0].arn : null
}
