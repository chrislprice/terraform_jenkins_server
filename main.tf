#Informs Terraform which cloud provider we're using and which region
provider "aws" {
  region  = "us-east-1"
}

#Creates security group for the Jenkins server. Allows port 22 and 8080 ingress traffic
#Allow connectiviy from any IP address
resource "aws_security_group" "jenkins-sg" {
  name_prefix = "jenkins-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Creates an EC2 t2.micro instance with Amazon Linux 2 AMI with Jenkins installed
#User_data command installs Jenkins during server creation
resource "aws_instance" "jenkins-server" {
  ami           = "ami-04581fbf744a7d11f"
  instance_type = "t2.micro"
  user_data = <<-EOF
  #!/bin/bash
  sudo yum update -y
  sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
  sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
  sudo yum upgrade -y
  sudo amazon-linux-extras install java-openjdk11 -y
  sudo yum install jenkins -y
  sudo systemctl daemon-reload
  sudo systemctl enable jenkins
  sudo systemctl start jenkins
  EOF

  #Assigns the key pair to allow SSH connectivity. 
  #Attaches the Jenkins security group to the instance
  vpc_security_group_ids = [aws_security_group.jenkins-sg.id]
  key_name = "WebServerKP"

  #Tag the instance with the name jenkins_server"
  tags = {
    Name = "jenkins_server"
  }
}

#This block of code creates the S3 bucket and block public access

#Creates random number for S3 bucket name since they have to be globally unique
resource "random_id" "randomidvalue" {
  byte_length = 10
}

#Create S3 bucket for Jenkins artifacts with the random value from above
resource "aws_s3_bucket" "jenkins-artifact-bucket" {
  bucket = "jenkins-artifacts-bucket-${random_id.randomidvalue.hex}"

  tags = {
    Name = "jenkins-artifacts-bucket"
  }
}

#Blocks public access to the newly created S3 bucket
resource "aws_s3_bucket_public_access_block" "block-jenkins-public-s3" {
  bucket = aws_s3_bucket.jenkins-artifact-bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
