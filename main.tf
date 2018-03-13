provider "aws" {
  region = "eu-central-1"
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.12.0.0/16"

  tags {
    Name = "lab"
  }
}

# Public

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "public"
  }
}

resource "aws_route" "public_to_internet" {
  route_table_id         = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.igw.id}"
}

resource "aws_subnet" "public" {
  vpc_id     = "${aws_vpc.vpc.id}"
  cidr_block = "${cidrsubnet(aws_vpc.vpc.cidr_block, 8, 0)}"

  tags {
    Name = "public"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.public.id}"
}

# Private

resource "aws_eip" "nat" {
  vpc = true

  tags {
    Name = "nat"
  }
}

resource "aws_nat_gateway" "nat" {
  subnet_id     = "${aws_subnet.public.id}"
  allocation_id = "${aws_eip.nat.id}"
}

resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "private"
  }
}

resource "aws_route" "private_to_internet" {
  route_table_id         = "${aws_route_table.private.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${aws_nat_gateway.nat.id}"
}

resource "aws_subnet" "private" {
  vpc_id     = "${aws_vpc.vpc.id}"
  cidr_block = "${cidrsubnet(aws_vpc.vpc.cidr_block, 8, 1)}"

  tags {
    Name = "private"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = "${aws_subnet.private.id}"
  route_table_id = "${aws_route_table.private.id}"
}

# Hosts

resource "aws_security_group" "hosts" {
  vpc_id = "${aws_vpc.vpc.id}"
  name   = "hosts"

  tags {
    Name = "hosts"
  }
}

resource "aws_security_group_rule" "egress" {
  security_group_id = "${aws_security_group.hosts.id}"
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  protocol          = "-1"
  from_port         = "0"
  to_port           = "65535"
}

resource "aws_security_group_rule" "self" {
  security_group_id = "${aws_security_group.hosts.id}"
  type              = "ingress"
  self              = true
  protocol          = "-1"
  from_port         = "0"
  to_port           = "65535"
}

resource "aws_security_group_rule" "ssh" {
  security_group_id = "${aws_security_group.hosts.id}"
  type              = "ingress"
  cidr_blocks       = ["${var.management_address}"]
  protocol          = "-1"
  from_port         = "0"
  to_port           = "65535"
}

resource "aws_instance" "hosts" {
  count                       = 2
  ami                         = "ami-337be65c"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = "${var.key_name}"
  subnet_id                   = "${aws_subnet.public.id}"
  vpc_security_group_ids      = ["${aws_security_group.hosts.id}"]

  user_data = <<EOF
#!/bin/bash

yum install -y docker
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
systemctl enable docker
reboot
EOF

  tags {
    Name = "host-${count.index + 1}"
  }
}
