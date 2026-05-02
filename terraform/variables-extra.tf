###############################################################
# Additional variables for ECS/ALB/VPC resources
###############################################################
variable "create_vpc" {
  description = "Set to true to create a new VPC, false to use existing"
  type        = bool
  default     = true
}

variable "existing_vpc_id" {
  description = "ID of existing VPC (used when create_vpc = false)"
  type        = string
  default     = ""
}

variable "existing_route_table_id" {
  description = "ID of existing route table (used when create_vpc = false)"
  type        = string
  default     = ""
}
