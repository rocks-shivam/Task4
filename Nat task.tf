provider "aws" {
  region   = "ap-south-1"
  profile  = "shivam2"
}
resource "tls_private_key" "mykey1" {
  algorithm   = "RSA"
}
resource "tls_private_key" "mykey2" {
  algorithm   = "RSA"
}
resource "tls_private_key" "mykey3" {
  algorithm   = "RSA"
}


resource "aws_key_pair" "mykey1" {
  key_name   = "wpkey1"
  public_key = tls_private_key.mykey1.public_key_openssh
}
resource "aws_key_pair" "mykey2" {
  key_name   = "sqlkey1"
  public_key = tls_private_key.mykey2.public_key_openssh
}
resource "aws_key_pair" "mykey3" {
  key_name   = "bastionkey1"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAwbC3lxcN3dbt1JuEYEDvS6YoVx0/3N1X7uWUYnzF8l98Ibe+Xtrjx+yepOOSNyLYAui1piJCL/zI9Dp8bFrrfnQbxV2aQs9jh7K3vIlGXKtKVIzsPgTL6sTlgKyQ3OdEC6b09bHQ5eNnHJikIZm/Ba+h6/aIBfoelItubJJdcTz60En5lkRh5HCf02JUTGeZBWs9odJalnW8J0MzOd5JltnuisSA1ftZXLk1Mzj5kE+x6atHONrXNafkcFI6pa9ry8QC00HaR2D8JlYQL0Tx5ksvIhS7ySEWtCrthb2oGN2k+/MJ9zgw+q7Ev/QmqTxsSeCG6llu3GNAk1kD7ZB7eQ=="
}


resource "aws_vpc" "vpc1" {
  cidr_block       = "10.1.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames  = true

  tags = {
    Name = "myvpc1"
  }
}
resource "aws_subnet" "subnet-1a" {
  vpc_id     = aws_vpc.vpc1.id
  cidr_block = "10.1.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "subnet-1a"
  }
}
resource "aws_subnet" "subnet-1b" {
  vpc_id     = aws_vpc.vpc1.id
  cidr_block = "10.1.2.0/24"
  availability_zone = "ap-south-1b"
  
  tags = {
    Name = "subnet-1b"
  }
}
resource "aws_internet_gateway" "ig_1" {
  depends_on = [aws_vpc.vpc1]
  vpc_id = aws_vpc.vpc1.id

  tags = {
    Name = "internet-gateway-1"
  }
}
resource "aws_route_table" "route_table" {
  depends_on = [aws_vpc.vpc1]
  vpc_id = aws_vpc.vpc1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig_1.id
  }

  tags = {
    Name = "route_table1"
  }
}
resource "aws_route_table_association" "a" {
  depends_on = [aws_route_table.route_table]
  subnet_id      = aws_subnet.subnet-1a.id
  route_table_id = aws_route_table.route_table.id
}
resource "aws_security_group" "wpsg" {
  depends_on = [aws_vpc.vpc1]
  name        = "wpsg1"
  description = "Allow ssh http and icmp"
  vpc_id      = aws_vpc.vpc1.id

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
ingress {
    description = "ICMP-IPv4"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wpsg1"
  }
}

resource "aws_security_group" "mysqlsg" {
  depends_on = [aws_security_group.wpsg]
  name        = "mysqlsg1"
  description = "Allow sql"
  vpc_id      = aws_vpc.vpc1.id

  ingress {
    description = "MYSQL"
    security_groups=[ "${aws_security_group.wpsg.id}" ]
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysqlsg1"
  }
}
resource "aws_security_group" "bastionsg" {
  depends_on = [aws_vpc.vpc1]
  name        = "bastionsg1"
  description = "Allow ssh for bastion"
  vpc_id      = aws_vpc.vpc1.id

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

  tags = {
    Name = "bastionsg1"
  }
}
resource "aws_security_group" "sqlallow" {
  depends_on = [aws_security_group.bastionsg]
  name        = "sqlallowsg1"
  description = "ssh allow to the mysql"
  vpc_id      = aws_vpc.vpc1.id

  ingress {
    description = "ssh"
    security_groups=[ "${aws_security_group.bastionsg.id}" ]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sqlallow1"
  }
}
resource "aws_instance" "wordpress" {
  depends_on = [aws_security_group.wpsg]
  ami           = "ami-0b5bff6d9495eff69"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.mykey1.key_name
  availability_zone = "ap-south-1a"
  subnet_id = aws_subnet.subnet-1a.id
  security_groups = [ "${aws_security_group.wpsg.id}" ]
  user_data = <<-EOF
                #! /bin/bash
                sudo su root
                yum install -y httpd24 php72 mysql57-server php72-mysqlnd -y
                service httpd start
                chkconfig httpd on
                service httpd enable
                cd /var/www/html
                wget https://wordpress.org/latest.tar.gz
                tar -xzf latest.tar.gz
                mv wordpress blog
                mv wp-config-sample.php wp-config.php
                          
  EOF
     
   tags = {
    Name = "wordpress"
  }
}
resource "aws_instance" "mysql" {
  depends_on = [aws_instance.bastionos]
  ami           = "ami-0b5bff6d9495eff69"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.mykey2.key_name
  availability_zone = "ap-south-1b"
  subnet_id = aws_subnet.subnet-1b.id
  security_groups = [ "${aws_security_group.mysqlsg.id}" , "${aws_security_group.sqlallow.id}"]
user_data = <<-EOF
                #! /bin/bash
                sudo su root
                sudo yum install -y httpd24 php72 mysql57-server php72-mysqlnd -y
                service mysqld start
                chkconfig mysqld on
                mysqladmin -u root password redhat

   EOF
  tags = {
    Name = "sqlos"
  }
}

resource "aws_instance" "bastionos" {
  depends_on = [aws_instance.wordpress]
  ami           = "ami-0ebc1ac48dfd14136"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.mykey3.key_name
  availability_zone = "ap-south-1a"
  subnet_id = "${aws_subnet.subnet-1a.id}"
  security_groups = [ "${aws_security_group.bastionsg.id}" ] 

  tags = {
    Name = "bastionos1"
  }
}

resource "aws_eip" "eip1" {
  vpc = true

  instance                  = aws_instance.mysql.id
  associate_with_private_ip = "*.*.*.*”
  depends_on                = ["aws_internet_gateway.ig_1"]
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.eip1.id
  subnet_id     = aws_subnet.subnet-1a.id

  tags = {
    Name = "hw_nat_gateway"
  }
}

resource "aws_route_table" "route_table2" {
  vpc_id = aws_vpc.vpc1.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
}


output "wpkey" {
  value = tls_private_key.mykey1.private_key_pem
}

output "sqlkey" {
  value = tls_private_key.mykey2.private_key_pem
}

















