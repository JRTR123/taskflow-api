# Taskflow production rollback runbook (on-call)

Use this when a **taskflow-pipeline** production/blue-green deploy is bad (health 500, pods CrashLoop, or users cannot hit the API). Do not improvise a new cluster.

## 1. Confirm blast radius (2 minutes)

On the Windows lab machine:

```powershell
$kc = Join-Path $PWD "k8s\kubeconfig.kind"
kubectl --kubeconfig $kc get svc taskflow -o yaml
kubectl --kubeconfig $kc get pods -l app=taskflow -o wide
kubectl --kubeconfig $kc logs -l app=taskflow --tail=50
```

- Live color is `spec.selector.color` on Service `taskflow` (`blue` or `green`).
- Jenkins artifacts `svc-taskflow-before.yaml` / `svc-taskflow-after.yaml` on the failed build show the last switch.

## 2. Instant traffic rollback (preferred)

Point the Service back at the previous color. If Jenkins already printed `Live color=green next=blue` and then failed, restore **green**:

```powershell
kubectl --kubeconfig $kc patch svc taskflow -p '{"spec":{"selector":{"app":"taskflow","color":"green"}}}'
kubectl --kubeconfig $kc run rb-smoke --rm -i --restart=Never --image=curlimages/curl:8.10.1 -- curl -sf http://taskflow:8080/health
```

Stop if `/health` is `{"status":"ok"}`. Tell the team: "traffic is on green; bad image is still on blue but not serving."

If the failed build used `FAIL_HEALTH=true`, that image returns HTTP 500 on `/health`. Switching color is the fix. Do not delete the cluster.

## 3. Roll the bad Deployment without switching color

Only if both colors are broken:

```powershell
kubectl --kubeconfig $kc rollout undo deployment/taskflow-blue
kubectl --kubeconfig $kc rollout undo deployment/taskflow-green
kubectl --kubeconfig $kc rollout status deployment/taskflow-blue --timeout=120s
```

Then smoke `/health` again.

## 4. Abort in-flight Jenkins work

- Open the red build → **Pipeline Steps** → Abort `input` / remaining stages.
- Do **not** tick `RUN_DEPLOY` or `FAIL_HEALTH` on a retry until health is green.
- Retry **Build with Parameters** with `FAIL_HEALTH` off so the SHA image is healthy.

## 5. LocalStack / Terraform (only if Lab 08 apply caused the incident)

```powershell
docker ps --filter name=localstack
# from repo, after a working pipeline workspace or local terraform:
# terraform -chdir=infra/terraform destroy -auto-approve
```

Do not commit `terraform.tfstate`. If apply created a dummy EC2 in LocalStack, destroy is enough; kind workloads are independent.

## 6. Notify

Post to Slack (or paste in the team channel) using the same text the pipeline sends:

`taskflow-api failure on origin/main <jenkins build url> — rolled svc taskflow selector back to <color>. /health ok.`

## 7. Do not

- `kind delete cluster` unless the control-plane is down.
- `kubectl delete ns default`
- Force-push `main`
- Re-apply `infra/terraform-insecure`
