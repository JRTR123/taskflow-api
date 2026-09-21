# One-time Lab 07 setup on this Windows machine (Docker Desktop).
# Usage: powershell -ExecutionPolicy Bypass -File scripts/lab07-setup.ps1

$ErrorActionPreference = 'Continue'
$kindDir = Join-Path $env:USERPROFILE 'bin'
$kindExe = Join-Path $kindDir 'kind.exe'
$env:Path = "$kindDir;$env:Path"

Write-Host "1) Local registry on :5000"
$reg = docker ps -a --filter "name=^registry$" --format "{{.Names}}"
if (-not $reg) {
  docker run -d -p 5000:5000 --name registry --restart unless-stopped registry:2
} else {
  docker start registry | Out-Null
}

Write-Host "2) kind cluster taskflow"
if (-not (Test-Path $kindExe)) {
  Write-Host "Installing kind to $kindExe ..."
  New-Item -ItemType Directory -Force -Path $kindDir | Out-Null
  Invoke-WebRequest -Uri "https://kind.sigs.k8s.io/dl/v0.27.0/kind-windows-amd64" -OutFile $kindExe
}

$clusters = & $kindExe get clusters 2>&1 | Where-Object { $_ -notmatch 'No kind clusters' }
if ($clusters -notcontains 'taskflow') {
  Write-Host "Creating kind cluster taskflow (first time takes a few minutes)..."
  & $kindExe create cluster --name taskflow
  if ($LASTEXITCODE -ne 0) { throw "kind create cluster failed" }
} else {
  Write-Host "Cluster taskflow already exists."
}

$kubeconfigKind = Join-Path $PSScriptRoot "..\k8s\kubeconfig.kind"
New-Item -ItemType Directory -Force -Path (Split-Path $kubeconfigKind) | Out-Null
& $kindExe get kubeconfig --name taskflow | Set-Content -Path $kubeconfigKind -Encoding ascii
$env:KUBECONFIG = (Resolve-Path $kubeconfigKind).Path

Write-Host "3) Connect registry + Jenkins agent to kind network"
docker network connect kind registry 2>$null | Out-Null
docker network connect kind jenkins-agent-v2 2>$null | Out-Null

Write-Host "4) Build and load init image"
docker build -t localhost:5000/taskflow-api:init .
if ($LASTEXITCODE -ne 0) { throw "docker build failed" }
docker push localhost:5000/taskflow-api:init
& $kindExe load docker-image localhost:5000/taskflow-api:init --name taskflow

Write-Host "5) Apply blue/green manifests (kubectl --kubeconfig kind, NOT Jenkins)"
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
kubectl --kubeconfig $env:KUBECONFIG apply -f (Join-Path $root 'k8s\taskflow-blue.yaml')
kubectl --kubeconfig $env:KUBECONFIG apply -f (Join-Path $root 'k8s\taskflow-green.yaml')
kubectl --kubeconfig $env:KUBECONFIG apply -f (Join-Path $root 'k8s\taskflow-svc.yaml')

Write-Host "6) Write kubeconfig for Jenkins agent (taskflow-control-plane hostname)"
$out = Join-Path $PSScriptRoot "..\k8s\kubeconfig.ci"
(Get-Content $kubeconfigKind) | ForEach-Object {
  $_ -replace 'https://127.0.0.1:\d+', 'https://taskflow-control-plane:6443' `
     -replace 'https://0.0.0.0:\d+', 'https://taskflow-control-plane:6443' `
     -replace 'https://localhost:\d+', 'https://taskflow-control-plane:6443'
} | Set-Content -Path $out -Encoding ascii

Write-Host ""
Write-Host "Done. Always use:"
Write-Host "  kubectl --kubeconfig $env:KUBECONFIG get svc taskflow -o yaml"
Write-Host "Live service:"
kubectl --kubeconfig $env:KUBECONFIG get svc taskflow -o yaml
