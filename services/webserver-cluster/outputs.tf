
output "dns-name" {

  value = aws_lb.lb-blm.dns_name
}
output "sg_id" {
  value = aws_security_group.allow_lb.id
}
