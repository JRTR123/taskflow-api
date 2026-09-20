# One-time SonarQube setup for Lab 05: coverage-only quality gate + Jenkins webhook.
# Usage: .\scripts\setup-sonar-lab-gate.ps1 -SonarUrl http://localhost:9000 -AdminToken YOUR_TOKEN -JenkinsUrl http://localhost:8080

param(
    [string]$SonarUrl = 'http://localhost:9000',
    [Parameter(Mandatory = $true)]
    [string]$AdminToken,
    [string]$JenkinsUrl = 'http://host.docker.internal:8080',
    [string]$GateName = 'Lab Taskflow Coverage',
    [string]$ProjectKey = 'taskflow-api'
)

$headers = @{ Authorization = "Bearer $AdminToken" }

function Invoke-SonarPost($path, $body) {
    Invoke-RestMethod -Method Post -Uri "$SonarUrl/api/$path" -Headers $headers -Body $body
}

Write-Host "Creating quality gate '$GateName'..."
try {
    $created = Invoke-SonarPost 'qualitygates/create' @{ name = $GateName }
    $gateId = $created.id
} catch {
    $gates = Invoke-RestMethod -Uri "$SonarUrl/api/qualitygates/list" -Headers $headers
    $gate = $gates.qualitygates | Where-Object { $_.name -eq $GateName } | Select-Object -First 1
    if (-not $gate) { throw $_ }
    $gateId = $gate.id
    Write-Host "Gate already exists (id=$gateId)."
}

Write-Host "Adding overall coverage < 70% condition..."
try {
    Invoke-SonarPost 'qualitygates/create_condition' @{
        gateId = $gateId
        metric = 'coverage'
        op     = 'LT'
        error  = '70'
    }
} catch {
    Write-Host "Condition may already exist: $($_.Exception.Message)"
}

Write-Host "Assigning gate to project $ProjectKey..."
Invoke-SonarPost 'qualitygates/select' @{ projectKey = $ProjectKey; gateId = $gateId }

Write-Host "Registering Jenkins webhook..."
try {
    Invoke-SonarPost 'webhooks/create' @{ name = 'jenkins'; url = "$JenkinsUrl/sonarqube-webhook/" }
} catch {
    Write-Host "Webhook may already exist: $($_.Exception.Message)"
}

Write-Host "Done. Re-run the Jenkins pipeline, then open:"
Write-Host "  $SonarUrl/dashboard?id=$ProjectKey"
