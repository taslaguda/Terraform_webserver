# Create a VPC
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
}

# Creates a key pair using a pre-generated public key, that is used to access the ec2 instance
resource "aws_key_pair" "webserver-keypair" {
  key_name   = "webserver-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# Creates an Internet Gateway to expose the VPC to allowed traffic from the internet 
resource "aws_internet_gateway" "vpc-igw" {
  vpc_id = aws_vpc.vpc.id
}

# This resource gets the details of the main route table to modify
data "aws_route_table" "main_route_table" {
  filter {
    name   = "association.main"
    values = ["true"]
  }
  filter {
    name   = "vpc-id"
    values = [aws_vpc.vpc.id]
  }
}
#This resource creates and modifies the main route table which was identified as a data resource.
resource "aws_default_route_table" "internet_route" {
  default_route_table_id = data.aws_route_table.main_route_table.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpc-igw.id
  }
  tags = {
    Name = "RouteTable"
  }
}

#This data block gets the details of the availability zones in the vpc 
data "aws_availability_zones" "azs" {
  state = "available"
}

#This resource creates a subnet in the first availability zone
resource "aws_subnet" "subnet" {
  availability_zone = element(data.aws_availability_zones.azs.names, 0)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
}

#Creates a security group that allows inbound traffic SSH and TCP traffic. The SSH traffic is for terraform to run remote commands on the server and the TCP traffic is for the webserver to be accessible over port 80
resource "aws_security_group" "webserver-sg" {
  name        = "webserver-sg"
  description = "Allow TCP/80 & TCP/22"
  vpc_id      = aws_vpc.vpc.id
  ingress {
    description = "Allow SSH traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "allow traffic from TCP/80"
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
}

# Prints out the public IP of the webserver
output "webserver-public-IP" {
  value = aws_instance.webserver.public_ip
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

#Create and bootstrap webserver
resource "aws_instance" "webserver" {
  ami                         =  data.aws_ami.ubuntu.id
  instance_type               = "t2.nano"
  key_name                    = aws_key_pair.webserver-keypair.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.webserver-sg.id]
  subnet_id                   = aws_subnet.subnet.id
  provisioner "remote-exec" {
    inline = [
      "sudo yum -y install httpd && sudo systemctl start httpd",
      "echo '<h1><center>The saved string is ${var.dynamic_string}</center></h1>' > index.html",
      "sudo mv index.html /var/www/html/"
    ]
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
  }
  tags = {
    Name = "webserver"
  }
}