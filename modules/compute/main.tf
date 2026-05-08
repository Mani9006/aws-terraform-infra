# ---------------------------------------------------------------------------
# Compute Module - Main Configuration
# ---------------------------------------------------------------------------
# Provisions EC2-based compute infrastructure with launch templates,
# auto scaling groups, application load balancers, and security groups.
# All resources follow the principle of least privilege.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Local Values
# ---------------------------------------------------------------------------

locals {
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags
  )

  # Use provided AMI or fetch latest Amazon Linux 2023
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2023.id

  # Determine whether to use key-based or SSM-based access
  use_key_pair = var.key_name != ""
}

# ---------------------------------------------------------------------------
# Data Sources
# ---------------------------------------------------------------------------

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# IAM Role and Instance Profile for EC2
# ---------------------------------------------------------------------------

resource "aws_iam_role" "ec2" {
  count = var.iam_instance_profile == "" ? 1 : 0

  name = "${var.project_name}-ec2-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "ec2_core" {
  count = var.iam_instance_profile == "" ? 1 : 0

  name = "${var.project_name}-ec2-core-policy"
  role = aws_iam_role.ec2[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # SSM access for Session Manager (recommended over SSH)
      {
        Sid    = "SSMCoreAccess"
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
          "ec2messages:AcknowledgeMessage",
          "ec2messages:DeleteMessage",
          "ec2messages:FailMessage",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages",
          "ec2messages:SendReply"
        ]
        Resource = "*"
      },
      # CloudWatch agent permissions
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ec2/${var.project_name}-${var.environment}*"
      },
      # S3 read-only for application assets
      {
        Sid    = "S3ReadAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-assets-${var.environment}-*",
          "arn:aws:s3:::${var.project_name}-assets-${var.environment}-*/*"
        ]
      },
      # ECR pull for containerized applications
      {
        Sid    = "ECRPull"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      # Secrets Manager read for application secrets
      {
        Sid    = "SecretsRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ec2_ssm_parameter" {
  count = var.iam_instance_profile == "" ? 1 : 0

  name = "${var.project_name}-ec2-ssm-policy"
  role = aws_iam_role.ec2[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SSMParameterRead"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  count = var.iam_instance_profile == "" ? 1 : 0

  name = "${var.project_name}-ec2-profile-${var.environment}"
  role = aws_iam_role.ec2[0].name

  tags = local.common_tags
}

locals {
  instance_profile_name = var.iam_instance_profile != "" ? var.iam_instance_profile : aws_iam_instance_profile.ec2[0].name
}

# ---------------------------------------------------------------------------
# Security Groups
# ---------------------------------------------------------------------------

# ALB Security Group - allows HTTP/HTTPS from internet
resource "aws_security_group" "alb" {
  count = var.enable_load_balancer ? 1 : 0

  name        = "${var.project_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  # HTTP from anywhere
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS from anywhere
  dynamic "ingress" {
    for_each = var.enable_https ? [1] : []
    content {
      description = "HTTPS from internet"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # Allow all outbound
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# EC2 Security Group - allows traffic only from ALB and VPC
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Security group for application EC2 instances"
  vpc_id      = var.vpc_id

  # HTTP from ALB only
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = var.enable_load_balancer ? [aws_security_group.alb[0].id] : []
  }

  # Application port from ALB only
  ingress {
    description     = "App port from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = var.enable_load_balancer ? [aws_security_group.alb[0].id] : []
  }

  # SSH access - only if key pair is provided
  dynamic "ingress" {
    for_each = local.use_key_pair ? [1] : []
    content {
      description = "SSH from VPC only"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr_block]
    }
  }

  # SSM Session Manager (no ingress needed - uses AWS API)

  # Allow all outbound
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ec2-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# KMS Key for EBS Encryption
# ---------------------------------------------------------------------------

resource "aws_kms_key" "ebs" {
  count = var.enable_volume_encryption ? 1 : 0

  description             = "KMS key for EBS volume encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = local.common_tags
}

resource "aws_kms_alias" "ebs" {
  count = var.enable_volume_encryption ? 1 : 0

  name          = "alias/${var.project_name}-ebs-${var.environment}"
  target_key_id = aws_kms_key.ebs[0].key_id
}

# ---------------------------------------------------------------------------
# Launch Template
# ---------------------------------------------------------------------------

resource "aws_launch_template" "app" {
  name          = "${var.project_name}-app-${var.environment}"
  image_id      = local.ami_id
  instance_type = var.instance_type
  key_name      = local.use_key_pair ? var.key_name : null

  iam_instance_profile {
    name = local.instance_profile_name
  }

  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = var.user_data != "" ? base64encode(var.user_data) : null

  monitoring {
    enabled = var.enable_monitoring
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 enforced
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = var.root_volume_type
      encrypted             = var.enable_volume_encryption
      kms_key_id            = var.enable_volume_encryption ? aws_kms_key.ebs[0].arn : null
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${var.project_name}-app-${var.environment}"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, {
      Name = "${var.project_name}-app-volume-${var.environment}"
    })
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# Application Load Balancer
# ---------------------------------------------------------------------------

resource "aws_lb" "app" {
  count = var.enable_load_balancer ? 1 : 0

  name               = "${var.project_name}-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection || var.environment == "prod"
  idle_timeout               = var.alb_idle_timeout

  access_logs {
    bucket  = var.alb_access_logs_enabled ? var.alb_access_logs_s3_bucket : ""
    enabled = var.alb_access_logs_enabled && var.alb_access_logs_s3_bucket != ""
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-alb-${var.environment}"
  })
}

# Target Group
resource "aws_lb_target_group" "app" {
  count = var.enable_load_balancer ? 1 : 0

  name     = "${var.project_name}-tg-${var.environment}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# HTTP Listener - redirects to HTTPS when enabled
resource "aws_lb_listener" "http" {
  count = var.enable_load_balancer ? 1 : 0

  load_balancer_arn = aws_lb.app[0].arn
  port              = "80"
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = var.enable_https ? [] : [1]
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.app[0].arn
    }
  }

  dynamic "default_action" {
    for_each = var.enable_https ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  count = var.enable_load_balancer && var.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.app[0].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[0].arn
  }
}

# ---------------------------------------------------------------------------
# Auto Scaling Group
# ---------------------------------------------------------------------------

resource "aws_autoscaling_group" "app" {
  name                      = "${var.project_name}-asg-${var.environment}"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  health_check_type         = var.enable_load_balancer ? "ELB" : "EC2"
  health_check_grace_period = var.health_check_grace_period
  vpc_zone_identifier       = var.private_subnet_ids
  termination_policies      = ["OldestLaunchTemplate", "Default"]
  default_instance_warmup   = var.instance_warmup

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  target_group_arns = var.enable_load_balancer ? [aws_lb_target_group.app[0].arn] : []

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-${var.environment}"
    propagate_at_launch = false
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "terraform"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = var.instance_warmup
    }
    triggers = ["tag"]
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# ---------------------------------------------------------------------------
# Scaling Policies
# ---------------------------------------------------------------------------

resource "aws_autoscaling_policy" "cpu_target_tracking" {
  count = var.enable_scaling_policies ? 1 : 0

  name                   = "${var.project_name}-cpu-tracking-${var.environment}"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target_value
  }
}

# ---------------------------------------------------------------------------
# CloudWatch Alarms for ASG
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-high-cpu-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = var.cpu_target_value
  alarm_description   = "Alarm when CPU exceeds ${var.cpu_target_value}%"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${var.project_name}-low-cpu-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 5
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 10
  alarm_description   = "Alarm when CPU drops below 10% - potential over-provisioning"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "instance_health" {
  alarm_name          = "${var.project_name}-unhealthy-instances-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Alarm when unhealthy host count exceeds 0"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    TargetGroup  = var.enable_load_balancer ? aws_lb_target_group.app[0].arn_suffix : ""
    LoadBalancer = var.enable_load_balancer ? aws_lb.app[0].arn_suffix : ""
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# SNS Topic for Alarms
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "alarms" {
  name = "${var.project_name}-alarms-${var.environment}"

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# CloudWatch Log Group for EC2 Instances
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "ec2" {
  name              = "/aws/ec2/${var.project_name}-${var.environment}"
  retention_in_days = var.environment == "prod" ? 90 : 30
  kms_key_id        = aws_kms_key.ebs[0].arn

  tags = local.common_tags
}
