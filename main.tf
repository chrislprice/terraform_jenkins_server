provider "aws" {
  region  = "us-east-1"
}

#Creates security group for the Jenkins server. Allows port 22 and 8080 ingress traffic
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

#Creates AWS EC2 instance with Jenkins installed
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

  #Assigned the key pair to allow SSH connectivity. Also, attached the jenkins-sg to the instance
  vpc_security_group_ids = [aws_security_group.jenkins-sg.id]
  key_name = "WebServerKP"

  #Tag the EC2 with the name "jenkins_server"
  tags = {
    Name = "jenkins_server"
  }
}


#Create random number for S3 bucket name
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
