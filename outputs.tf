output "this" {
  value = aws_instance.this
}

output "public_ips" {
  value = aws_eip.this
}

output "security_group_id" {
  value = one(module.security_group[*].this.id)
}