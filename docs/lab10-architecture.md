# Taskflow Lab 10 — architecture (one page)

```mermaid
flowchart TB
  subgraph scm["GitHub JRTR123/taskflow-api"]
    apiJ["Jenkinsfile"]
    mobJ["taskflow-mobile/Jenkinsfile"]
  end

  subgraph jenkins["Jenkins controller :8080"]
    cloud["Kubernetes cloud kind / template k8s-node"]
    q["Build queue"]
  end

  subgraph kind["kind cluster taskflow"]
    podA["API agent pod: node:20-alpine + dind"]
    podM["Mobile agent pod: cirruslabs/flutter + dind"]
  end

  subgraph verify["Verify parallel"]
    lint["Lint"]
    unit["Unit Test"]
    sast["SAST ESLint + Semgrep"]
    sca["SCA npm audit"]
    secrets["Gitleaks"]
  end

  subgraph ordered["Dependent sequence"]
    inst["Install npm ci"]
    prep["scan-result.json"]
    sbom["Syft SBOM + Cosign"]
    opa["OPA Policy Gate"]
    sonar["SonarQube + Quality Gate"]
    img["Build Image SHA tag"]
    trivy["Trivy"]
    bg["Blue/Green kind"]
    iac["IaC lint / plan / apply"]
    health["Pipeline Health Gate Prometheus"]
    prod["Deploy Production"]
  end

  subgraph obs["Lab 09 observability"]
    prom["Prometheus :9090"]
    graf["Grafana :3000"]
    am["Alertmanager :9093"]
  end

  scm --> jenkins
  jenkins --> cloud
  cloud --> podA
  cloud --> podM
  q --> cloud
  podA --> inst --> verify --> prep --> sbom --> opa --> sonar --> img --> trivy --> bg --> iac --> health --> prod
  podM --> fa["flutter analyze"] --> ft["flutter test"] --> fosv["osv-scanner"] --> apk["debug APK"] --> aab["release AAB on main"]
  prod --> notify["Slack webhook notify-webhook"]
  jenkins --> prom
  health --> prom
  prom --> graf
  prom --> am
```

## taskflow-api order

1. Agent Tools (docker CLI + kubectl + wait for dind)
2. Install
3. **parallel Verify:** Lint, Unit Test, SAST, SCA, Secrets Detection
4. Prepare Security Scan Result
5. SBOM + Sign (credential `cosign-pass`)
6. OPA Policy Gate — **blocks CRITICAL**
7. SonarQube Analysis + Quality Gate
8. Build Image → Container Scan → Blue/Green Deploy
9. IaC validate / tfsec / optional Terraform apply
10. Pipeline Health Gate — **blocks production if 24h success rate < 90%**
11. Deploy Staging (`develop`) / Deploy Production (`main` + `RUN_DEPLOY`)
12. post: Slack/email via `notify-webhook`

## taskflow-mobile order

Analyze → Test → SCA (osv-scanner) → debug APK (every branch) → signed AAB (`main` + `SIGN_ANDROID`)

## Credentials (Jenkins, never in Git)

| Id | Use |
| --- | --- |
| `cosign-pass` | Cosign key passphrase |
| `localstack-aws` | LocalStack access keys |
| `notify-webhook` | Slack incoming webhook |
| `android-keystore` / `android-storepass` / `android-keypass` / `android-keyalias` | Release AAB |
| SonarQube server config | `withSonarQubeEnv` |
