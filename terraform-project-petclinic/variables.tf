# varible for the vpc IP range
variable "cidr_vpc" {
  description = "VPC CIDR"
  default     = "10.0.0.0/16"
}

# varibles four our 2 AZs in region eu-west-3
variable "az_a" {
  description = "Availaility zone a"
  default     = "eu-west-3a"
}

variable "az_b" {
  description = "Availaility zone b"
  default     = "eu-west-3b"
}

# cidr variable for the four subnets
variable "cidr_public_subnet_a" {
  description = "CIDR for public subnet a"
  default     = "10.0.0.0/24"
}

variable "cidr_public_subnet_b" {
  description = "CIDR for public subnet b"
  default     = "10.0.1.0/24"
}