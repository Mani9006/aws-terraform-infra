# ---------------------------------------------------------------------------
# Compute Module - Variables
# ---------------------------------------------------------------------------
# Variables for provisioning EC2-based compute resources including launch
# templates, auto scaling groups, and application load balancers.
# ---------------------------------------------------------------------------

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Project name used for resource naming and tagging."
  type        = string
  default     = "aws-infra"
}

variable "vpc_id" {
  description = "ID of the VPC where compute resources will be deployed."
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the load balancer placement."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EC2 instance placement."
  type        = list(string)
}

variable "vpc_cidr_block" {
  description = "CIDR block of the VPC for security group ingress rules."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the application servers."
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances. If empty, the latest Amazon Linux 2023 AMI will be used."
  type        = string
  default     = ""
}

variable "min_size" {
  description = "Minimum number of instances in the auto scaling group."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances in the auto scaling group."
  type        = number
  default     = 6
}

variable "desired_capacity" {
  description = "Desired number of instances in the auto scaling group."
  type        = number
  default     = 2
}

variable "enable_scaling_policies" {
  description = "Enable target tracking scaling policies on the auto scaling group."
  type        = bool
  default     = true
}

variable "cpu_target_value" {
  description = "Target CPU utilization percentage for auto scaling."
  type        = number
  default     = 60

  validation {
    condition     = var.cpu_target_value > 0 && var.cpu_target_value <= 100
    error_message = "CPU target value must be between 1 and 100."
  }
}

variable "enable_load_balancer" {
  description = "Enable the Application Load Balancer for the compute tier."
  type        = bool
  default     = true
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on the load balancer. Always true in production."
  type        = bool
  default     = false
}

variable "enable_https" {
  description = "Enable HTTPS listener on the load balancer. Requires ACM certificate ARN."
  type        = bool
  default     = false
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS termination. Required if enable_https is true."
  type        = string
  default     = ""
}

variable "health_check_path" {
  description = "Health check path for the target group."
  type        = string
  default     = "/health"
}

variable "enable_monitoring" {
  description = "Enable detailed CloudWatch monitoring for EC2 instances."
  type        = bool
  default     = true
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB."
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 1000
    error_message = "Root volume size must be between 8 and 1000 GB."
  }
}

variable "root_volume_type" {
  description = "Type of the root EBS volume."
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.root_volume_type)
    error_message = "Root volume type must be one of: gp2, gp3, io1, io2."
  }
}

variable "enable_volume_encryption" {
  description = "Enable encryption for EBS root volumes."
  type        = bool
  default     = true
}

variable "key_name" {
  description = "Name of the EC2 key pair for SSH access. If empty, SSM Session Manager is used instead."
  type        = string
  default     = ""
}

variable "iam_instance_profile" {
  description = "IAM instance profile name for EC2 instances. If empty, a profile is created."
  type        = string
  default     = ""
}

variable "user_data" {
  description = "User data script for EC2 instance initialization. Base64 encoded automatically."
  type        = string
  default     = ""
}

variable "associate_public_ip_address" {
  description = "Associate public IP addresses with instances. Should be false for private subnets."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to all compute resources."
  type        = map(string)
  default     = {}
}

variable "alb_idle_timeout" {
  description = "Idle timeout for the ALB in seconds."
  type        = number
  default     = 60
}

variable "alb_access_logs_enabled" {
  description = "Enable access logs for the ALB. Requires S3 bucket for logs."
  type        = bool
  default     = true
}

variable "alb_access_logs_s3_bucket" {
  description = "S3 bucket name for ALB access logs."
  type        = string
  default     = ""
}

variable "enable_termination_protection" {
  description = "Enable termination protection on the auto scaling group instances."
  type        = bool
  default     = false
}

variable "health_check_grace_period" {
  description = "Grace period in seconds before health checks begin."
  type        = number
  default     = 300
}

variable "instance_warmup" {
  description = "Warmup time in seconds for new instances before they count toward metrics."
  type        = number
  default     = 120
}
