###############################################################
# terraform/outputs.tf
###############################################################

output "public_ip" {
  description = "Elastic IP — your permanent public address"
  value       = aws_eip.hermes.public_ip
}

output "public_dns" {
  description = "EC2 public DNS"
  value       = aws_instance.hermes.public_dns
}

output "instance_id" {
  description = "EC2 instance ID (use for SSM sessions)"
  value       = aws_instance.hermes.id
}

output "ssh_command" {
  description = "SSH into your instance"
  value       = "ssh ubuntu@${aws_eip.hermes.public_ip}"
}

output "hermes_web_url" {
  description = "Hermes gateway web URL"
  value       = "http://${aws_eip.hermes.public_ip}"
}

output "ssm_session_command" {
  description = "Open a shell via AWS SSM (no SSH key needed)"
  value       = "aws ssm start-session --target ${aws_instance.hermes.id} --region ${var.aws_region}"
}
