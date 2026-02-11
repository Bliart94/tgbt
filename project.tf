data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_subnet" "public-a" {
  filter {
    name   = "tag:Name"
    values = ["PUBLIC_SUBNET_A"]
  }
}

data "aws_subnet" "public-b" {
  filter {
    name   = "tag:Name"
    values = ["PUBLIC_SUBNET_B"]
  }
}

data "aws_subnet" "private-a" {
  filter {
    name   = "tag:Name"
    values = ["PRIVATE_SUBNET_A"]
  }
}

data "aws_subnet" "private-b" {
  filter {
    name   = "tag:Name"
    values = ["PRIVATE_SUBNET_B"]
  }
}

data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = ["VPC"]
  }
}

data "aws_security_group" "bastion" {
  filter {
    name   = "tag:Name"
    values = ["SG_BASTION_EC2"]
  }
}

data "aws_ami" "amazon-linux-2" {
  most_recent = true


  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }


  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

resource "aws_security_group" "ec2" {
  name        = "${var.identifiant}_SG_EC2"
  description = "ec2 Security Group"
  vpc_id      = data.aws_vpc.selected.id
  tags        = { Name = "${var.identifiant}_SG_EC2" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allow_ec2_to_bastion" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = data.aws_security_group.bastion.id
  security_group_id        = aws_security_group.ec2.id
}

resource "aws_instance" "vm" {
  ami                    = data.aws_ami.amazon-linux-2.id
  subnet_id              = data.aws_subnet.private-a.id
  availability_zone      = data.aws_availability_zones.available.names[0]
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = aws_key_pair.ec2.id

  tags = { Name = upper("${var.identifiant}_VM") }
}

resource "aws_key_pair" "ec2" {
   key_name   = lower("${var.identifiant}_key")
   public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDDbSEyblVHab2wlXSAFOe2mvUdH9/Y1rNR++eftlaiEfaU1dNX9/mwcuO/4zbqYRRZJFL7jJDWYvMMKMfnaNv0/VslWJ0wauv9MeSrr8QiHM8N3hGnw9AtVLuoL89cI3ClLfaDPoFAMSMO/OMZ5Ijf5O6ezCWUCnTPOrlbdaZ+XMBIEW9Rf+sgQ6WfdU8M4uacStO6T181TrCl/EA3D0iSHJuSohbP8oe67zDVTWdo4npcPFQ6RMGOaRS5Rq3FyrJG61cvyEBYozzeOMGGd3jvK/UxcQBF2aalz/9NvHl+cYeRCS/bekkfZXfxYi+uh10ZIj2SzroVOYpa1rzdnRjP"
}


resource "aws_db_subnet_group" "default" {
  name       = lower("${var.identifiant}_SUBNET_GROUP_RDS")
  subnet_ids = [data.aws_subnet.private-a.id, data.aws_subnet.private-b.id]

  tags = {
    Name = "${var.identifiant}_SUBNET_GROUP_RDS"
  }
}

resource "aws_security_group_rule" "ec2_to_http" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.ec2.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ec2_to_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.ec2.id
  cidr_blocks       = ["0.0.0.0/0"]
}

data "aws_security_group" "lb" {
  filter {
    name   = "tag:Name"
    values = ["SG_LB"]
  }
}

data "aws_lb" "lb" {
  name = "lb"
}