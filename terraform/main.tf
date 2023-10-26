provider "aws" {
  profile = var.profile
  region  = var.region
}

# Create VPC and its Component
module "vpc" {
  source              = "terraform-aws-modules/vpc/aws"
  name                = "${var.project-name}-vpc"
  cidr                = var.cidr
  azs                 = var.az
  public_subnets      = var.public-cidr
  private_subnets     = var.private-cidr
  public_subnet_tags  = { Name = "public-subnet" }
  private_subnet_tags = { Name = "private-subnet" }
  enable_nat_gateway  = true
  single_nat_gateway  = true
  create_igw          = true
  tags = {
    Environment = "${var.project-name}"
    Terraform   = "true"
    Name        = "${var.project-name}"
  }
}

# RSA key of size 4096 bits
resource "tls_private_key" "keypair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
# creating private key locally
resource "local_file" "keypair" {
  content         = tls_private_key.keypair.private_key_pem
  filename        = "${var.project-name}-key.pem"
  file_permission = "600"
}
# creating keypair
resource "aws_key_pair" "keypair" {
  key_name   = "${var.project-name}-key"
  public_key = tls_private_key.keypair.public_key_openssh
}

# Create a security group
resource "aws_security_group" "k8s_security_group" {
  vpc_id = module.vpc.vpc_id
  tags = {
    Name = "${var.project-name}-K8s-sg"
  }
}
resource "aws_security_group_rule" "allow-all-ingress" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = [var.cidr]
  security_group_id = aws_security_group.k8s_security_group.id
}
resource "aws_security_group_rule" "allow-all-egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k8s_security_group.id
}
resource "aws_security_group_rule" "allow-ssh-connections" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k8s_security_group.id
}

# security group for jenkins node
resource "aws_security_group" "jenkins-sg" {
  vpc_id = module.vpc.vpc_id
  tags = {
    Name = "${var.project-name}-jenkins-sg"
  }
}
resource "aws_security_group_rule" "allow-ssh-connections-2" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.jenkins-sg.id
}
resource "aws_security_group_rule" "allow-igress-2" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.jenkins-sg.id
}
resource "aws_security_group_rule" "allow-all-egress-2" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.jenkins-sg.id
}

# security group for load balancer
resource "aws_security_group" "lb-sg" {
  vpc_id = module.vpc.vpc_id
  tags = {
    Name = "${var.project-name}-lb-sg"
  }
}
resource "aws_security_group_rule" "allow-igress-3" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lb-sg.id
}
resource "aws_security_group_rule" "allow-all-egress-2" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.jenkins-sg.id
}

# creating jenkns server
resource "aws_instance" "jenkins" {
  ami                         = var.ami
  instance_type               = "t2.medium"
  subnet_id                   = module.vpc.public_subnets[1]
  vpc_security_group_ids      = [aws_security_group.jenkins-sg.id]
  key_name                    = aws_key_pair.keypair.id
  associate_public_ip_address = true
  user_data                   = file("./userdata/jenkins.sh")
  tags = {
    Name = "${var.project-name}-jenkins"
  }
}

# creating proxy/ansible server
resource "aws_instance" "ansible" {
  ami                         = var.ami
  instance_type               = "t2.micro"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.k8s_security_group.id]
  key_name                    = aws_key_pair.keypair.id
  associate_public_ip_address = true
  user_data = templatefile("./userdata/ansible.sh", {
    prv_key = tls_private_key.keypair.private_key_pem,
    master  = aws_instance.master.private_ip,
    worker1 = aws_instance.worker.*.private_ip[0],
    worker2 = aws_instance.worker.*.private_ip[1]
  })
  tags = {
    Name = "${var.project-name}-ansible"
  }
}

# create null resource to copy playbooks folder into ansible/proxy server
resource "null_resource" "copy-playbooks" {
  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = aws_instance.ansible.public_ip
    private_key = tls_private_key.keypair.private_key_pem
  }
  provisioner "file" {
    source      = "./playbooks"
    destination = "/home/ubuntu/playbooks"
  }
}

# creating 1 master node
resource "aws_instance" "master" {
  ami                    = var.ami
  instance_type          = "t2.medium"
  subnet_id              = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.k8s_security_group.id]
  key_name               = aws_key_pair.keypair.id
  user_data              = <<-EOF
#!/bin/bash
sudo hostnamectl set-hostname master-$(hostname -i)
EOF
  tags = {
    Name = "${var.project-name}-master"
  }
}

# creating 2 worker nodes
resource "aws_instance" "worker" {
  count                  = 2
  ami                    = var.ami
  instance_type          = "t2.medium"
  subnet_id              = element(module.vpc.private_subnets, count.index)
  vpc_security_group_ids = [aws_security_group.k8s_security_group.id]
  key_name               = aws_key_pair.keypair.id
  user_data              = <<-EOF
#!/bin/bash
sudo hostnamectl set-hostname worker-$(hostname -i)
EOF
  tags = {
    Name = "${var.project-name}-worker-${count.index + 1}"
  }
}

# create load balancer
resource "aws_lb" "lb" {
  name               = "${var.project-name}-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.lb-sg.id]

  tags = {
    Name = "${var.project-name}-lb"
  }
}

# create target-group
resource "aws_lb_target_group" "tg" {
  name     = "${var.project-name}-tg"
  port     = 30001
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 5
    interval            = 30
    timeout             = 5
    path                = "/"
  }
}

# create http listener
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# create target-group-attachment
resource "aws_lb_target_group_attachment" "tg-attachment" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.worker[count.index].id
  port             = 30001
  count            = 2
}

# import my hosted zone from my aws account
data "aws_route53_zone" "route53" {
  name         = var.domain_name
  private_zone = false
}

# Create stage record from Route 53 zone
resource "aws_route53_record" "record" {
  zone_id = data.aws_route53_zone.route53.zone_id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = aws_lb.lb.dns_name
    zone_id                = aws_lb.lb.zone_id
    evaluate_target_health = true
  }
}

#create acm certificate
resource "aws_acm_certificate" "acm_certificate" {
  domain_name               = var.domain_name
  subject_alternative_names = [var.domain_name2]
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

#create route53 validation record
resource "aws_route53_record" "validation_record" {
  for_each = {
    for dvo in aws_acm_certificate.acm_certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.route53.zone_id
}

#create acm certificate validition
resource "aws_acm_certificate_validation" "acm_certificate_validation" {
  certificate_arn         = aws_acm_certificate.acm_certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.validation_record : record.fqdn]
}