package security

deny[msg] {
    input.vulnerabilities[_].severity == "CRITICAL"
    msg := "Blocked: found a CRITICAL CVE"
}

deny[msg] {
    input.vulnerabilities[_].severity == "CRITICAL"
    input.vulnerabilities[_].id != ""
    msg := sprintf(
        "Blocked: CRITICAL vulnerability %s",
        [input.vulnerabilities[_].id]
    )
}