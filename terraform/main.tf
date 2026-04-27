provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

resource "aws_security_group" "web_sg" {
  name_prefix = "allow-web-and-ssh-"
  description = "Permetti SSH e traffico Django"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
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

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_key_pair" "deploy_key" {
  key_name   = "deploy-key-${data.aws_caller_identity.current.account_id}"
  public_key = var.deploy_ssh_public_key
}

resource "aws_instance" "web_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.deploy_key.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y docker.io docker-compose
              systemctl enable --now docker

              # Creazione utente deploy
              useradd -m -s /bin/bash deploy
              usermod -aG docker deploy

              # Configurazione SSH per deploy
              mkdir -p /home/deploy/.ssh
              echo "${var.deploy_ssh_public_key}" > /home/deploy/.ssh/authorized_keys
              chown -R deploy:deploy /home/deploy/.ssh
              chmod 700 /home/deploy/.ssh
              EOF

  tags = { Name = "Django-Production" }
}

output "ec2_public_ip" {
  description = "L'IP pubblico dell'istanza EC2"
  value       = aws_instance.web_server.public_ip
}