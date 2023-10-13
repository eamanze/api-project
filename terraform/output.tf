output "master" {
  value = aws_instance.master.private_ip
}
output "workers" {
  value = aws_instance.worker.*.private_ip
}
output "proxy" {
  value = aws_instance.haproxy.public_ip
}