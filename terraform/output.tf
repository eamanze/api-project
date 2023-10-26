output "master" {
  value = aws_instance.master.private_ip
}
output "workers" {
  value = aws_instance.worker.*.private_ip
}
output "proxy" {
  value = aws_instance.ansible.public_ip
}
output "jenkins" {
  value = aws_instance.jenkins.public_ip
}
output "lb" {
  value = aws_lb.lb.dns_name
}