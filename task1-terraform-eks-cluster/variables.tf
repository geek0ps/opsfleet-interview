variable "cidr_block" {
  default = "10.0.0.0/16"
}
variable "cluster_name" {
  type        = string
  default     = "opsfleet-core"
  description = "The EKS Cluster name"
}

variable "node_group_name" {
  type        = string
  default     = "opsfleet-ng"
  description = "node group name"
}

variable "disk_size" {
  type        = number
  default     = 100
  description = "Volume size to attach"
}

variable "instance_types" {
  default     = ["t3.medium"]
  description = "The instane type to use"
}

variable "desired_size" {
  default = 1
}

variable "max_size" {
  default = 2
}

variable "min_size" {
  default = 1
}

variable "max_unavailable" {
  default = 1
}

variable "service_account_name" {
  default = "aws-s3-access"
}