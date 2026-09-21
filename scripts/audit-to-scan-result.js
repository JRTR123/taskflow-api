#!/usr/bin/env node
/**
 * Convert `npm audit --json` into the OPA input shape:
 * { "vulnerabilities": [ { "id", "severity", "cvss" } ] }
 */
const fs = require('fs');

const src = process.argv[2] || 'audit.json';
const dest = process.argv[3] || 'scan-result.json';
const audit = JSON.parse(fs.readFileSync(src, 'utf8'));

const vulnerabilities = Object.values(audit.vulnerabilities || {}).map((v) => {
  const via = Array.isArray(v.via) ? v.via : [];
  const advisory = via.find((x) => x && typeof x === 'object');
  return {
    id: (advisory && (advisory.source || advisory.url)) || v.name,
    name: v.name,
    severity: String(v.severity || '').toUpperCase(),
    cvss: advisory && typeof advisory.cvss === 'object' ? advisory.cvss.score : undefined,
  };
});

fs.writeFileSync(dest, JSON.stringify({ vulnerabilities }, null, 2));
console.log(`Wrote ${dest} (${vulnerabilities.length} vulnerabilities)`);
