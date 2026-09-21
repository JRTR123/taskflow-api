# Intentionally insecure copy for Lab 08 "before" screenshots.
# Scan with: docker run --rm -v ${PWD}:/src aquasec/tfsec /src/infra/terraform-insecure
# Do not apply this in Jenkins.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "open" {
  name        = "wide-open"
  description = "insecure lab sample"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "open" {
  ami                    = "ami-12345678"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.open.id]

  root_block_device {
    encrypted = false
  }
}
