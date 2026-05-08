# ---------------------------------------------------------------------------
# Storage Module - Variables
# ---------------------------------------------------------------------------
# Variables for provisioning S3 buckets with encryption, versioning,
# lifecycle policies, access logging, and access controls.
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
  description = "Project name for resource naming and tagging."
  type        = string
  default     = "aws-infra"
}

variable "bucket_name_override" {
  description = "Override the bucket name. If empty, name is auto-generated."
  type        = string
  default     = ""
}

variable "enable_versioning" {
  description = "Enable S3 versioning for object recovery and audit."
  type        = bool
  default     = true
}

variable "enable_encryption" {
  description = "Enable server-side encryption with KMS."
  type        = bool
  default     = true
}

variable "encryption_type" {
  description = "Encryption type: SSE-S3 (AES256) or SSE-KMS."
  type        = string
  default     = "SSE-KMS"

  validation {
    condition     = contains(["SSE-S3", "SSE-KMS"], var.encryption_type)
    error_message = "Encryption type must be SSE-S3 or SSE-KMS."
  }
}

variable "enable_access_logging" {
  description = "Enable access logging to a separate logging bucket."
  type        = bool
  default     = true
}

variable "enable_lifecycle_policy" {
  description = "Enable lifecycle policies for object transitions and expiration."
  type        = bool
  default     = true
}

variable "noncurrent_version_expiration_days" {
  description = "Days after which non-current object versions expire."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_expiration_days >= 30
    error_message = "Non-current version expiration must be at least 30 days."
  }
}

variable "transition_to_ia_days" {
  description = "Days after which objects transition to Standard-IA storage class."
  type        = number
  default     = 30
}

variable "transition_to_glacier_days" {
  description = "Days after which objects transition to Glacier storage class."
  type        = number
  default     = 90
}

variable "enable_replication" {
  description = "Enable cross-region replication. Only for production."
  type        = bool
  default     = false
}

variable "replication_destination_region" {
  description = "Destination region for cross-region replication."
  type        = string
  default     = "us-west-2"
}

variable "block_public_access" {
  description = "Block all public access to the bucket. Should always be true."
  type        = bool
  default     = true
}

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS. Empty = no CORS."
  type        = list(string)
  default     = []
}

variable "cors_allowed_methods" {
  description = "List of allowed HTTP methods for CORS."
  type        = list(string)
  default     = ["GET", "HEAD"]
}

variable "enable_website_hosting" {
  description = "Enable static website hosting. Only for static asset buckets."
  type        = bool
  default     = false
}

variable "website_index_document" {
  description = "Index document for website hosting."
  type        = string
  default     = "index.html"
}

variable "website_error_document" {
  description = "Error document for website hosting."
  type        = string
  default     = "error.html"
}

variable "enable_object_lock" {
  description = "Enable S3 Object Lock for compliance."
  type        = bool
  default     = false
}

variable "object_lock_retention_days" {
  description = "Default retention period in days for Object Lock."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Additional tags to apply to all storage resources."
  type        = map(string)
  default     = {}
}

variable "enable_event_notifications" {
  description = "Enable S3 event notifications to SNS/SQS."
  type        = bool
  default     = false
}

variable "bucket_policy_statements" {
  description = "Additional bucket policy statements."
  type        = list(any)
  default     = []
}

variable "force_destroy" {
  description = "Force destroy bucket contents on bucket deletion. Never true in production."
  type        = bool
  default     = false
}
