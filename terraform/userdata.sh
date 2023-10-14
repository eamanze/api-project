#!/bin/bash

# Update package lists and upgrade existing packages.
sudo apt update
apt-get upgrade -y

# Switch to superuser mode.
sudo -i

# Install software-properties-common for managing repository information.
apt install --no-install-recommends software-properties-common

# Add the HAProxy PPA repository for version 2.4.
add-apt-repository ppa:vbernat/haproxy-2.4 -y

# Install HAProxy version 2.4.
apt install haproxy=2.4.* -y

# Configure HAProxy with frontend and backend settings.
sudo bash -c 'echo "
frontend fe-apiserver
bind 0.0.0.0:6443
mode tcp
option tcplog
default_backend be-apiserver
 
backend be-apiserver
mode tcp
option tcplog
option tcp-check
balance roundrobin
default-server inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100
 
    server master1 ${master}:6443 check" > /etc/haproxy/haproxy.cfg'

# Restart the HAProxy service to apply the configuration changes.
systemctl restart haproxy

# Update instance and install ansible
sudo apt-get update -y
sudo apt-get install software-properties-common -y
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt-get install ansible python3-pip -y
sudo su -c "pip3 install kubernetes" ubuntu
sudo bash -c ' echo "strictHostKeyChecking No" >> /etc/ssh/ssh_config'

# Update instance and install ansible
sudo apt update -y
sudo apt install docker.io -y
sudo usermod -aG docker ubuntu
sudo systemctl start docker
sudo systemctl enable docker
sudo chmod 777 /var/run/docker.sock
sudo systemctl restart docker

# Copying Private Key into Ansible Server and chaning its permission
echo "${prv_key}" >> /home/ubuntu/key.pem
sudo chmod 400 /home/ubuntu/key.pem
sudo chown ubuntu:ubuntu /home/ubuntu/key.pem

# Giving the right permission to Ansible Directory
sudo chown -R ubuntu:ubuntu /etc/ansible && chmod +x /etc/ansible
sudo chmod 777 /etc/ansible/hosts
sudo chown -R ubuntu:ubuntu /etc/ansible

# Copying the 1st HAproxy IP into our ha-ip.yml
sudo echo Main_haIP: $(hostname -I | awk '{print $1}') > /home/ubuntu/ha-ip.yml

# Updating Host inventory file with all the ip addresses
sudo echo "[master]" >> /etc/ansible/hosts
sudo echo "${master} ansible_ssh_private_key_file=/home/ubuntu/key.pem" >> /etc/ansible/hosts
sudo echo "[worker]" >> /etc/ansible/hosts
sudo echo "${worker1} ansible_ssh_private_key_file=/home/ubuntu/key.pem" >> /etc/ansible/hosts 
sudo echo "${worker2} ansible_ssh_private_key_file=/home/ubuntu/key.pem" >> /etc/ansible/hosts

# Executing all playbooks
sudo su -c "ansible-playbook /home/ubuntu/playbooks/setup.yml" ubuntu
sudo su -c "ansible-playbook /home/ubuntu/playbooks/init.yml" ubuntu
sudo su -c "ansible-playbook /home/ubuntu/playbooks/deployment.yml" ubuntu

sudo hostnamectl set-hostname Ansible