variable "aws_region" {
  type        = string
  description = "AWS region used with LocalStack"
  default     = "us-east-1"
}

variable "aws_endpoint" {
  type        = string
  description = "LocalStack edge endpoint"
  default     = "http://host.docker.internal:4566"
}

variable "allowed_cidr" {
  type        = string
  description = "CIDR allowed to reach the Taskflow API on port 8080"
  default     = "10.0.0.0/8"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "ami_id" {
  type        = string
  description = "AMI id (dummy id is accepted by LocalStack)"
  default     = "ami-12345678"
}
