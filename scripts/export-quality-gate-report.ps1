# Export a printable quality gate report (open HTML in browser -> Print -> Save as PDF).
# Create .sonar-token.local with your SonarQube token (same as Jenkins sonar-token credential).

param(
    [string]$SonarUrl = 'http://localhost:9000',
    [string]$ProjectKey = 'taskflow-api',
    [string]$TokenFile = (Join-Path $PSScriptRoot '..\.sonar-token.local'),
    [string]$OutDir = (Join-Path $PSScriptRoot '..\deliverables')
)

if (-not (Test-Path $TokenFile)) {
    Write-Error "Missing token file: $TokenFile`nPaste your SonarQube project/user token into that file (one line, no quotes)."
}

$token = (Get-Content $TokenFile -Raw).Trim()
$headers = @{ Authorization = "Bearer $token" }

$status = Invoke-RestMethod -Uri "$SonarUrl/api/qualitygates/project_status?projectKey=$ProjectKey" -Headers $headers
$measures = Invoke-RestMethod -Uri "$SonarUrl/api/measures/component?component=$ProjectKey&metricKeys=coverage,ncloc,bugs,vulnerabilities" -Headers $headers

$gateStatus = $status.projectStatus.status
$conditions = $status.projectStatus.conditions
$coverage = ($measures.component.measures | Where-Object { $_.metric -eq 'coverage' }).value

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
$outHtml = Join-Path $OutDir 'quality-gate-report.html'

$rows = ($conditions | ForEach-Object {
    $s = if ($_.status -eq 'OK') { 'pass' } else { 'fail' }
    @"
<tr class="$s"><td>$($_.metricKey)</td><td>$($_.comparator) $($_.errorThreshold)</td><td>$($_.actualValue)</td><td>$($_.status)</td></tr>
"@
}) -join "`n"

@"

<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <title>SonarQube Quality Gate — $ProjectKey</title>
  <style>
    body { font-family: Segoe UI, Arial, sans-serif; margin: 2rem; color: #1a1a1a; }
    h1 { font-size: 1.4rem; }
    .ok { color: #0a0; font-weight: bold; }
    .err { color: #c00; font-weight: bold; }
    table { border-collapse: collapse; width: 100%; margin-top: 1rem; }
    th, td { border: 1px solid #ccc; padding: 0.5rem 0.75rem; text-align: left; }
    th { background: #f4f4f4; }
    tr.fail td { background: #fff0f0; }
    tr.pass td { background: #f6fff6; }
    .meta { color: #555; margin-bottom: 1.5rem; }
  </style>
</head>
<body>
  <h1>SonarQube Quality Gate Report</h1>
  <p class="meta">Project: <strong>$ProjectKey</strong> · Server: $SonarUrl · Generated: $stamp</p>
  <p>Overall status: <span class="$(if ($gateStatus -eq 'OK') { 'ok' } else { 'err' })">$gateStatus</span></p>
  <p>Line coverage (overall): <strong>$coverage%</strong></p>
  <h2>Conditions</h2>
  <table>
    <thead><tr><th>Metric</th><th>Threshold</th><th>Actual</th><th>Status</th></tr></thead>
    <tbody>
      $rows
    </tbody>
  </table>
  <p class="meta">Lab deliverable: use browser Print → Save as PDF.</p>
</body>
</html>
"@ | Set-Content -Path $outHtml -Encoding UTF8

Write-Host "Wrote $outHtml"
if ($gateStatus -eq 'OK') {
    Write-Host "Quality gate PASSED — open the HTML and print to PDF."
} else {
    Write-Host "Quality gate is $gateStatus — fix Sonar gate (coverage-only) or re-run analysis with full tests."
}
