variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "availability_zone" {
  type    = string
  default = "us-east-1a"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_pair_name" {
  type = string
}

variable "public_key_path" {
  type = string
}

variable "ec2_cidr_blocks" {
  type    = string
  default = "0.0.0.0/0"
}

variable "sandbox_eip_allocation_id" {
  type        = string
  description = "Optional. If you already allocated an Elastic IP, set the allocation id. Leave empty to skip."
  default     = ""
}

variable "sandbox_fqdn" {
  type        = string
  description = "Optional. Used for nginx server_name. If empty, nginx will accept any host."
  default     = ""
}
