# Lab 09: kind agents + Prometheus/Grafana on this Windows + Docker Desktop machine.
# Usage: powershell -ExecutionPolicy Bypass -File scripts/lab09-setup.ps1

$ErrorActionPreference = 'Continue'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$kindDir = Join-Path $env:USERPROFILE 'bin'
$kindExe = Join-Path $kindDir 'kind.exe'
$env:Path = "$kindDir;$env:Path"
$kubeconfigKind = Join-Path $root 'k8s\kubeconfig.kind'

Write-Host "1) kind cluster taskflow"
if (Test-Path $kindExe) {
  $clusters = & $kindExe get clusters 2>&1 | Where-Object { $_ -notmatch 'No kind clusters' }
  if ($clusters -notcontains 'taskflow') {
    Write-Host "Run scripts/lab07-setup.ps1 first (kind cluster missing)."
  } else {
    & $kindExe get kubeconfig --name taskflow | Set-Content -Path $kubeconfigKind -Encoding ascii
    $env:KUBECONFIG = (Resolve-Path $kubeconfigKind).Path
  }
} else {
  Write-Host "kind.exe not found. Run scripts/lab07-setup.ps1 first."
}

if ($env:KUBECONFIG) {
  Write-Host "2) RBAC namespace jenkins-agents"
  kubectl --kubeconfig $env:KUBECONFIG apply -f (Join-Path $root 'k8s\jenkins-agent-rbac.yaml')
}

Write-Host "3) Attach Jenkins containers to the kind network (pods must reach :8080 and :50000)"
$jenkinsNames = docker ps --format '{{.Names}}' | Where-Object { $_ -match 'jenkins' }
foreach ($n in $jenkinsNames) {
  docker network connect kind $n 2>$null | Out-Null
  Write-Host "   connected $n -> kind"
}
if (-not $jenkinsNames) {
  Write-Host "   no running container named *jenkins* — connect it manually: docker network connect kind <jenkins>"
}

Write-Host "4) Prometheus + Grafana + Alertmanager"
docker compose -f (Join-Path $root 'observability\docker-compose.yml') up -d

Write-Host ""
Write-Host "URLs"
Write-Host "  Jenkins metrics  http://localhost:8080/prometheus"
Write-Host "  Prometheus       http://localhost:9090"
Write-Host "  Prometheus alerts http://localhost:9090/alerts"
Write-Host "  Alertmanager     http://localhost:9093"
Write-Host "  Grafana          http://localhost:3000  (admin / admin)"
Write-Host "  Dashboard JSON   observability/grafana/dashboards/jenkins-slo.json"
Write-Host ""
Write-Host "Do this in Jenkins UI BEFORE the next build:"
Write-Host "  A) Manage Jenkins -> Plugins -> Available"
Write-Host "       install  Kubernetes"
Write-Host "       install  Prometheus metrics"
Write-Host "     Restart Jenkins when asked."
Write-Host "  B) Open http://localhost:8080/prometheus — you should see jenkins_* lines."
Write-Host "     If 403: Manage Jenkins -> Security -> allow authenticated users Metrics/View"
Write-Host "     or uncheck authentication on the Prometheus plugin section."
Write-Host "  C) Manage Jenkins -> Clouds -> New cloud -> Kubernetes"
Write-Host "       Name: kind"
Write-Host "       Kubernetes URL: https://taskflow-control-plane:6443"
Write-Host "       Check: Disable https certificate check"
Write-Host "       Credentials: Secret file = k8s/kubeconfig.kind (full kubeconfig)"
Write-Host "       Jenkins URL: http://host.docker.internal:8080"
Write-Host "       Jenkins tunnel: host.docker.internal:50000"
Write-Host "       Namespace: jenkins-agents"
Write-Host "     Pod Template:"
Write-Host "       Name: k8s-node"
Write-Host "       Labels: k8s-node"
Write-Host "       Concurrency / Cap: 2   (raise to 10 after the queue-alert screenshot)"
Write-Host "       Container name: node"
Write-Host "       Image: node:20-alpine"
Write-Host "       Command: cat"
Write-Host "       Allocate TTY: yes"
Write-Host ""
Write-Host "Builds:"
Write-Host "  1) taskflow-pipeline -> Build with Parameters -> tick RUN_K8S_AGENT"
Write-Host "     In another terminal:  kubectl --kubeconfig k8s/kubeconfig.kind get pods -n jenkins-agents -w"
Write-Host "  2) New Item taskflow-k8s-agent, Pipeline from SCM, Script Path Jenkinsfile.lab09"
Write-Host "     Trigger that job 10 times with Cap=2 to fire JenkinsQueueBacklog"
Write-Host "     Then set Cap=10, trigger again, wait for the alert to clear"
Write-Host ""
Write-Host "Watch pods:"
Write-Host "  kubectl --kubeconfig $kubeconfigKind get pods -n jenkins-agents -w"
