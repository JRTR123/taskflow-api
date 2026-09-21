#!/bin/sh
# Build an Ansible inventory from Terraform outputs (Lab 08).
set -e
cd "$(dirname "$0")/../infra/terraform"
ADDR=$(terraform output -raw instance_address 2>/dev/null || echo 127.0.0.1)
cat > ../ansible/inventory.ini <<EOF
[taskflow]
taskflow-api ansible_host=localhost ansible_connection=local ansible_python_interpreter=auto_silent
# terraform instance_address=${ADDR}
EOF
echo "Wrote infra/ansible/inventory.ini for address ${ADDR}"
