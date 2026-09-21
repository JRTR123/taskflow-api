# Start LocalStack and the Terraform state bucket for Lab 08.
$ErrorActionPreference = 'Continue'

$name = docker ps -a --filter "name=^localstack$" --format "{{.Names}}"
if (-not $name) {
  docker run -d --name localstack -p 4566:4566 -e SERVICES=ec2,s3,sts,iam localstack/localstack:3.8
} else {
  docker start localstack | Out-Null
}

Write-Host "Waiting for LocalStack..."
for ($i = 0; $i -lt 30; $i++) {
  try {
    Invoke-WebRequest -UseBasicParsing http://localhost:4566/_localstack/health -TimeoutSec 2 | Out-Null
    break
  } catch {
    Start-Sleep -Seconds 2
  }
}

docker run --rm --add-host=host.docker.internal:host-gateway `
  -e AWS_ACCESS_KEY_ID=test -e AWS_SECRET_ACCESS_KEY=test -e AWS_DEFAULT_REGION=us-east-1 `
  amazon/aws-cli:2.17.54 `
  --endpoint-url http://host.docker.internal:4566 s3 mb s3://taskflow-tfstate 2>$null

Write-Host "LocalStack ready on http://localhost:4566  bucket=taskflow-tfstate"
Write-Host "Before/after tfsec screenshots:"
Write-Host "  docker run --rm -v ${PWD}:/src aquasec/tfsec /src/infra/terraform-insecure"
Write-Host "  docker run --rm -v ${PWD}:/src aquasec/tfsec /src/infra/terraform"
