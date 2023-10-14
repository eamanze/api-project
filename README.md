# Project Name - Api-project

## Introduction

This project builds an application using Python that exposes a REST endpoint that returns the following JSON payload with the current timestamp and a static message:


```bash
{
  “message”: “Automate all the things!”,
  “timestamp”: 1529729125
}
```

The application is then deployed into a kubernetes cluster created using kubeadm.
This repository contains the Terraform code to deploy resources on your AWS account.  This README provides step-by-step instructions on how to execute the Terraform code in this project to deploy resources on your AWS account.


## Tech Stack used

Infrastructure as code (IAC) – Terraform

Cloud infrastructure - AWS core services (VPC, Subnet, ec2 instance, load balancer, etc.)

Version Control System (VCS) – Github

Configuration Management - Ansible

Programming Language - Python

Entry point to cluster - HAProxy


## Prerequisites

Before you begin, make sure you have the following prerequisites:

1. An AWS account - You'll need an active AWS account to deploy resources using this Terraform code.
2. AWS CLI - Install the AWS Command Line Interface (CLI) on your local machine and configure it with your AWS credentials.
3. Terraform - Install Terraform on your local machine.
4. Git - Install Git on your local machine to clone this repository.


## Deployment Steps

Follow these steps to deploy resources on your AWS account using Terraform:


### Step 1: Clone the Repository

Clone this GitHub repository to your local machine using the following command:

```bash
git clone https://github.com/eamanze/api-project.git
```


## Step 2: Navigate to the Project Directory

Change your working directory to the cloned repository:

```bash
cd api-project/terraform/
```


## Step 3: Set your values in the ```credentials.tfvars``` file in other to spin up the infrastructure in your AWS account

Important:
Before applying the Terraform configuration, ensure that you update the following variables with your own values in the variable.tf file:

```bash
profile      = ""
region       = ""
project-name = ""
ami          = ""
cidr         = "10.0.0.0/16"
az           = ["us-west-2a", "us-west-2b"]
public-cidr  = ["10.0.1.0/24", "10.0.2.0/24"]
private-cidr = ["10.0.3.0/24", "10.0.4.0/24"]
```


## Step 4: Initialize Terraform

Run the following command to initialize Terraform and download the necessary providers:

```bash
terraform init
```


## Step 5: Plan the Deployment

Run the following command to see what changes Terraform will apply without actually deploying anything:

```bash
terraform plan -var-file credentials.tfvars
```

Review the output to ensure that Terraform will create the desired resources with the expected changes.


## Step 6: Deploy Resources

If everything looks good in the plan, proceed with deploying the resources:

```bash
terraform apply -var-file credentials.tfvars -auto-approve
```


```Note: After finishing the preceding command and process, wait for approximately 15 minutes to allow the completion of all the playbooks in the ansible/haproxy server. Then, in order to view the application, copy the load balancer dns generated from the terraform output into your browser.```


## Step 7: Clean Up

```bash
terraform destroy -var-file credentials.tfvars -auto-approve
```


Thanks!!!