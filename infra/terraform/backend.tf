terraform {
  backend "s3" {
    bucket                      = "taskflow-tfstate"
    key                         = "taskflow/terraform.tfstate"
    region                      = "us-east-1"
    endpoint                    = "http://host.docker.internal:4566"
    access_key                  = "test"
    secret_key                  = "test"
    encrypt                     = true
    use_path_style              = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}
