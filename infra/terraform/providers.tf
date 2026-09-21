terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # 5.54+ calls DescribeInstanceTypes after RunInstances ("collecting instance settings").
      # LocalStack Community does not return t3 instance-type metadata, so apply fails.
      version = "5.46.0"
    }
  }
}

provider "aws" {
  region                      = var.aws_region
  access_key                  = "test"
  secret_key                  = "test"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true

  endpoints {
    apigateway     = var.aws_endpoint
    cloudwatch     = var.aws_endpoint
    ec2            = var.aws_endpoint
    elasticache    = var.aws_endpoint
    iam            = var.aws_endpoint
    kinesis        = var.aws_endpoint
    lambda         = var.aws_endpoint
    rds            = var.aws_endpoint
    s3             = var.aws_endpoint
    secretsmanager = var.aws_endpoint
    ses            = var.aws_endpoint
    sns            = var.aws_endpoint
    sqs            = var.aws_endpoint
    ssm            = var.aws_endpoint
    stepfunctions  = var.aws_endpoint
    sts            = var.aws_endpoint
  }
}
