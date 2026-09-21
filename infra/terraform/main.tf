resource "aws_security_group" "taskflow" {
  name        = "taskflow-api-sg"
  description = "Allow Taskflow API traffic on 8080 from a restricted CIDR"

  ingress {
    description = "Taskflow API HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    description = "HTTPS to pull container images"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    description = "HTTP to local registry"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  tags = {
    Name    = "taskflow-api-sg"
    Project = "taskflow"
  }
}

resource "aws_instance" "taskflow" {
  ami           = var.ami_id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.taskflow.id]
  monitoring             = true
  # LocalStack CE has no instance-type catalog; ebs_optimized triggers that lookup.
  ebs_optimized          = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp2"
    volume_size = 8
  }

  tags = {
    Name    = "taskflow-api"
    Project = "taskflow"
  }
}
