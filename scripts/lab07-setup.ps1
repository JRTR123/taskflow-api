# One-time Lab 07 setup on this Windows machine (Docker Desktop).
# Usage: powershell -ExecutionPolicy Bypass -File scripts/lab07-setup.ps1

$ErrorActionPreference = 'Stop'

Write-Host "1) Local registry on :5000"
$reg = docker ps -a --filter name=^registry$ --format '{{.Names}}'
if (-not $reg) {
  docker run -d -p 5000:5000 --name registry --restart unless-stopped registry:2
} else {
  docker start registry | Out-Null
}

Write-Host "2) kind cluster taskflow"
if (-not (Get-Command kind -ErrorAction SilentlyContinue)) {
  Write-Host "Installing kind to %USERPROFILE%\bin\kind.exe ..."
  New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\bin" | Out-Null
  Invoke-WebRequest -Uri "https://kind.sigs.k8s.io/dl/v0.27.0/kind-windows-amd64" -OutFile "$env:USERPROFILE\bin\kind.exe"
  $env:Path = "$env:USERPROFILE\bin;$env:Path"
}

$existing = kind get clusters 2>$null
if ($existing -notcontains 'taskflow') {
  kind create cluster --name taskflow
}

Write-Host "3) Connect registry + Jenkins agent to kind network"
docker network connect kind registry 2>$null
docker network connect kind jenkins-agent-v2 2>$null

Write-Host "4) Build and load init image"
docker build -t localhost:5000/taskflow-api:init .
docker push localhost:5000/taskflow-api:init
kind load docker-image localhost:5000/taskflow-api:init --name taskflow

Write-Host "5) Apply blue/green manifests"
kubectl config use-context kind-taskflow
kubectl apply -f k8s/taskflow-blue.yaml
kubectl apply -f k8s/taskflow-green.yaml
kubectl apply -f k8s/taskflow-svc.yaml

Write-Host "6) Write kubeconfig for Jenkins (in-cluster hostname)"
$out = Join-Path $PSScriptRoot "..\k8s\kubeconfig.ci"
kind get kubeconfig --name taskflow | ForEach-Object {
  $_ -replace 'https://127.0.0.1:\d+', 'https://taskflow-control-plane:6443' `
     -replace 'https://0.0.0.0:\d+', 'https://taskflow-control-plane:6443'
} | Set-Content -Path $out -Encoding ascii

Write-Host "Done. Live service selector:"
kubectl get svc taskflow -o yaml
Write-Host "Commit k8s/kubeconfig.ci is gitignored. Copy it onto the Jenkins agent workspace after checkout, or keep it in the repo working tree so the pipeline can read WORKSPACE/k8s/kubeconfig.ci"
