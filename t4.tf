provider "aws" {
  region = "ap-south-1"
  profile = "mytejas"
}


resource "aws_vpc" "t4vpc" {
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = "true"

  tags = {
    Name = "t4vpc"
  }
}


resource "aws_subnet" "t4public" {
  vpc_id     = aws_vpc.t4vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = "true"
  depends_on = [aws_vpc.t4vpc]

  tags = {
    Name = "t4public"
  }
}


resource "aws_subnet" "t4private" {
  vpc_id     = aws_vpc.t4vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = "false"
  depends_on = [aws_vpc.t4vpc]

  tags = {
    Name = "t4private"
  }
}


resource "aws_internet_gateway" "t4ig" {
  vpc_id = aws_vpc.t4vpc.id
  depends_on = [aws_vpc.t4vpc]

  tags = {
    Name = "t4ig"
  }
}


resource "aws_route_table" "t4table1" {
  vpc_id = aws_vpc.t4vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.t4ig.id
  }
  depends_on = [aws_vpc.t4vpc]

  tags = {
    Name = "t4table1"
  }
}


resource "aws_route_table_association" "t4associate1" {
  subnet_id      = aws_subnet.t4public.id
  route_table_id = aws_route_table.t4table1.id
  depends_on = [aws_subnet.t4public]
}


resource "aws_route_table" "t4table2" {
  vpc_id = aws_vpc.t4vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.t4ng.id
  }
  depends_on = [aws_vpc.t4vpc]

  tags = {
    Name = "t4table2"
  }
}


resource "aws_route_table_association" "t4associate2" {
  subnet_id      = aws_subnet.t4private.id
  route_table_id = aws_route_table.t4table2.id
  depends_on = [aws_subnet.t4public]
}


resource "aws_security_group" "t4sg" {
  name        = "t4sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.t4vpc.id


 ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


 ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = [aws_vpc.t4vpc]

  tags = {
    Name = "t4sg"
  }
}


resource "aws_instance" "t4wpos" {
  ami           = "ami-049cbce295a54b26b"
  instance_type = "t2.micro"
  key_name      = "mykey"
  subnet_id =  aws_subnet.t4public.id
  vpc_security_group_ids = [ "${aws_security_group.t4sg.id}" ]
  
  tags = {
    Name = "t4wpos"
  }
}

output "wordpress_public_ip"{
  value=aws_instance.t4wpos.public_ip
}


resource "aws_security_group" "t4mysqlsg" {
  name        = "basic"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.t4vpc.id


  ingress {
    description = "t3mysql"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  depends_on = [aws_vpc.t4vpc]

  tags = {
    Name = "t4mysqlsg"
  }
}


resource "aws_instance" "t4mysqlos" {
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  key_name      = "mykey"
  subnet_id =  aws_subnet.t4private.id
  vpc_security_group_ids = [ aws_security_group.t4mysqlsg.id ]
  
  tags = {
    Name = "t4mysqlos"
  }
}


resource "aws_eip" "t4eip" {
  depends_on = [aws_vpc.t4vpc]

  vpc      = true
  
  tags = {
    Name = "t4eip"
  }
}


resource "aws_nat_gateway" "t4ng" {
  depends_on = [aws_vpc.t4vpc,aws_subnet.t4public,aws_eip.t4eip]

  allocation_id = aws_eip.t4eip.id
  subnet_id     = aws_subnet.t4public.id

  tags = {
    Name = "t4ng"
  }
}


resource "null_resource" "null" {
depends_on = [aws_instance.t4wpos,aws_instance.t4mysqlos,
             aws_eip.t4eip,aws_nat_gateway.t4ng,
	     aws_route_table.t4table2,aws_route_table_association.t4associate2]

connection {
        type        = "ssh"
    	user        = "ec2-user"
    	private_key = file("C:/Users/HP/Downloads/mykey.pem")
        host     = aws_instance.t4wpos.public_ip
        }

provisioner "local-exec" {    
      command = "start chrome http://${aws_instance.t4wpos.public_ip}/wordpress"
   }
}