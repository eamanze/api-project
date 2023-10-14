provider "aws" {
  profile = var.profile
  region  = var.region
}

# Create VPC and Component
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
#creating private key
resource "local_file" "keypair" {
  content         = tls_private_key.keypair.private_key_pem
  filename        = "${var.project-name}-key.pem"
  file_permission = "600"
}
# creating ec2 keypair
resource "aws_key_pair" "keypair" {
  key_name   = "${var.project-name}-key"
  public_key = tls_private_key.keypair.public_key_openssh
}

# security group for docker
resource "aws_security_group" "sg" {
  name        = "${var.project-name}-sg"
  description = "Allow Inbound Traffic"
  vpc_id      = module.vpc.vpc_id
  ingress {
    description = "all port"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    name = "${var.project-name}-sg"
  }
}


#creating Ec2 for master
resource "aws_instance" "haproxy" {
  ami                         = "ami-0ecc74eca1d66d8a6"
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.sg.id]
  key_name                    = aws_key_pair.keypair.id
  associate_public_ip_address = true
  user_data = templatefile("./userdata.sh", {
    prv_key = tls_private_key.keypair.private_key_pem,
    master  = aws_instance.master.private_ip,
    worker1 = aws_instance.worker.*.private_ip[0],
    worker2 = aws_instance.worker.*.private_ip[1]
  })
  tags = {
    Name = "${var.project-name}-haproxy"
  }
}

#create null resource to copy playbooks directory into proxy server
resource "null_resource" "copy-playbooks" {
  connection {
    type                = "ssh"
    user                = "ubuntu"
    host                = aws_instance.haproxy.public_ip
    private_key         = tls_private_key.keypair.private_key_pem
  }
  provisioner "file" {
    source      = "./playbooks"
    destination = "/home/ubuntu/playbooks"
  }
}

#creating Ec2 for master
resource "aws_instance" "master" {
  ami                    = "ami-0ecc74eca1d66d8a6"
  instance_type          = "t2.medium"
  subnet_id              = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.sg.id]
  key_name               = aws_key_pair.keypair.id
  user_data              = <<-EOF
#!/bin/bash
sudo hostnamectl set-hostname master-$(hostname -i)
EOF
  tags = {
    Name = "${var.project-name}-master"
  }
}

#creating Ec2 for worker1
resource "aws_instance" "worker" {
  count                  = 2
  ami                    = "ami-0ecc74eca1d66d8a6"
  instance_type          = "t2.medium"
  subnet_id              = element(module.vpc.private_subnets, count.index)
  vpc_security_group_ids = [aws_security_group.sg.id]
  key_name               = aws_key_pair.keypair.id
  user_data              = <<-EOF
#!/bin/bash
sudo hostnamectl set-hostname worker-$(hostname -i)
EOF
  tags = {
    Name = "${var.project-name}-worker-${count.index + 1}"
  }
}

# security group for docker
resource "aws_security_group" "lb-sg" {
  name        = "${var.project-name}-lb-sg"
  description = "Allow Inbound Traffic"
  vpc_id      = module.vpc.vpc_id
  ingress {
    description = "all port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    name = "${var.project-name}-lb-sg"
  }
}

# create grafana loadbalancer
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
    path                = "/get_data"
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# resource "aws_lb_listener" "tg-listener2" {
#   load_balancer_arn = aws_lb.tg.arn
#   port              = "443"
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   certificate_arn   = var.acm_certificate
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.tg.arn
#   }
# }

resource "aws_lb_target_group_attachment" "tg-attachment" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.worker[count.index].id
  port             = 30001
  count            = 2
}