# Lab 10 extras on top of Lab 09. ASCII only for Windows PowerShell.
# Usage: powershell -ExecutionPolicy Bypass -File scripts/lab10-setup.ps1

$ErrorActionPreference = 'Continue'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$kindDir = Join-Path $env:USERPROFILE 'bin'
$env:Path = "$kindDir;$env:Path"
$kubeconfigKind = Join-Path $root 'k8s\kubeconfig.kind'

if (Test-Path (Join-Path $kindDir 'kind.exe')) {
  & (Join-Path $kindDir 'kind.exe') get kubeconfig --name taskflow | Set-Content -Path $kubeconfigKind -Encoding ascii
  $env:KUBECONFIG = (Resolve-Path $kubeconfigKind).Path
  kubectl --kubeconfig $env:KUBECONFIG apply -f (Join-Path $root 'k8s\jenkins-agent-rbac.yaml')
}

Write-Host 'Jenkins credentials to create (Manage Jenkins -> Credentials -> Global):'
Write-Host '  cosign-pass          Secret text   (Cosign passphrase)'
Write-Host '  localstack-aws       Username/password  user=test  pass=test'
Write-Host '  notify-webhook       Secret text   Slack incoming webhook URL'
Write-Host '  android-keystore     Secret file   (release AAB only)'
Write-Host '  android-storepass    Secret text'
Write-Host '  android-keypass      Secret text'
Write-Host '  android-keyalias     Secret text'
Write-Host ''
Write-Host 'New Jenkins job taskflow-mobile:'
Write-Host '  Pipeline from SCM, Script Path = taskflow-mobile/Jenkinsfile'
Write-Host ''
Write-Host 'Screenshot files:'
Write-Host '  docs/lab10-architecture.md'
Write-Host '  docs/lab10-rollback-runbook.md'
Write-Host ''
Write-Host 'Demo blocker: Policy Gate (CRITICAL CVE) or FAIL_HEALTH=true (blue/green smoke fails).'
