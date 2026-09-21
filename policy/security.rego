package security

deny[msg] {
  input.vulnerabilities[_].severity == "CRITICAL"
  msg := "Blocked: found a CRITICAL CVE"
}

deny[msg] {
  vuln := input.vulnerabilities[_]
  vuln.severity == "CRITICAL"
  vuln.id != ""
  msg := sprintf("Blocked: CRITICAL vulnerability %s", [vuln.id])
}
