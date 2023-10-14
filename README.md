# Project Name - Api-project

## Introduction

This project involves creating a Python application that provides a REST endpoint. This endpoint returns a JSON response containing the current timestamp along with a static message.:


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


## Application Breakdown

This code creates a basic web application that provides two routes. The first route ("/get_data") returns a JSON response with a message and a timestamp, while the second route ("/") displays a welcome message when the main page is accessed. 


### Importing Libraries:

The code starts by importing two libraries: Flask and jsonify.
Flask is a Python framework used for building web applications.
jsonify is a utility function provided by Flask to create JSON responses.


### Initializing the Flask App:

app = Flask(__name__) creates an instance of the Flask application.
This instance is used to define routes and handle incoming requests.


### Defining a Route - "/get_data":

@app.route("/get_data", methods=["GET"]) is a decorator indicating that the function below it should be executed when a request is made to the "/get_data" route.
The methods=["GET"] part specifies that this route will only respond to HTTP GET requests.


### Handling the "/get_data" Request:

Inside the get_data() function, the current timestamp is calculated using the time.time() function.
It creates a dictionary named data containing a message and the timestamp.


### Returning a JSON Response:

The function returns jsonify(data), which converts the data dictionary into a JSON-formatted response.


### Defining Another Route - "/":

@app.route("/", methods=["GET"]) sets up a route for the root URL path ("/"). This means that when a user visits the main page of the application, the function index() will be called.


### Handling the "/" Request:

The index() function returns a simple string: "Welcome to my Flask app!". This will be displayed in the browser when a user visits the root URL.


### Running the Application:

The final block if __name__ == "__main__": checks if the script is being run directly.
If it is being run directly, it starts the Flask application with app.run().
The debug=True flag provides additional information for development, and host="0.0.0.0" makes the app accessible from all network interfaces on the machine.


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


```Note: After finishing the preceding command and process, wait for approximately 15 minutes to allow the completion of all the playbooks in the ansible/haproxy server. Then, in order to view the application, copy the load balancer dns generated from the terraform output into your browser.

When a user accesses the URL path /get_data with a GET request
```


## Step 7: Clean Up

```bash
terraform destroy -var-file credentials.tfvars -auto-approve
```


Thanks!!!