# Lab 05 — Quality gate report (PDF)

1. In SonarQube: **My Account → Security → Generate Token** (or reuse `sonar-token` from Jenkins).
2. Save the token as one line in `.sonar-token.local` at the repo root.
3. Run:

```powershell
.\scripts\setup-sonar-lab-gate.ps1 -AdminToken YOUR_TOKEN -JenkinsUrl http://host.docker.internal:8080
.\scripts\export-quality-gate-report.ps1
```

4. Open `deliverables/quality-gate-report.html` → **Print → Save as PDF**.

After a **green** Jenkins build (Quality Gate stage), the report should show status **OK** and coverage ≥ 70%.
