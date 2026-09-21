output "instance_id" {
  description = "EC2 instance id"
  value       = aws_instance.taskflow.id
}

output "instance_address" {
  description = "Reachable address of the Taskflow instance"
  value       = coalesce(aws_instance.taskflow.public_ip, aws_instance.taskflow.private_ip)
}

output "security_group_id" {
  description = "Security group attached to the instance"
  value       = aws_security_group.taskflow.id
}
