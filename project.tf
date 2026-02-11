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
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "state"
    values = ["available"]
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

resource "aws_instance" "api" {
  ami                    = data.aws_ami.amazon-linux-2.id
  subnet_id              = data.aws_subnet.private-a.id
  availability_zone      = data.aws_availability_zones.available.names[0]
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.sg_api.id]
  key_name               = aws_key_pair.ec2.id

  tags = { Name = upper("${var.identifiant}_VM_api") }
}

# SG API
resource "aws_security_group" "sg_api" {
  name        = "${var.identifiant}_SG_API"
  description = "SG for TBGT API VM"
  vpc_id      = data.aws_vpc.selected.id
  tags = { Name = "${var.identifiant}_SG_API" }
}

# SG SITE
resource "aws_security_group" "sg_site" {
  name        = "${var.identifiant}_SG_SITE"
  description = "SG for TBGT SITE VM"
  vpc_id      = data.aws_vpc.selected.id
  tags = { Name = "${var.identifiant}_SG_SITE" }
}

resource "aws_security_group_rule" "ssh_api_from_bastion" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.sg_api.id
  source_security_group_id = data.aws_security_group.bastion.id
}

resource "aws_security_group_rule" "ssh_site_from_bastion" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.sg_site.id
  source_security_group_id = data.aws_security_group.bastion.id
}

resource "aws_security_group_rule" "api_8000_from_site" {
  type                     = "ingress"
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.sg_api.id
  source_security_group_id = aws_security_group.sg_site.id
}

resource "aws_security_group_rule" "site_from_lb_8080" {
  type                     = "ingress"
  security_group_id        = aws_security_group.sg_site.id
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = data.aws_security_group.lb.id
}

resource "aws_security_group_rule" "api_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.sg_api.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "site_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.sg_site.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_instance" "site" {
  ami                    = data.aws_ami.amazon-linux-2.id
  subnet_id              = data.aws_subnet.private-a.id
  availability_zone      = data.aws_availability_zones.available.names[0]
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.sg_site.id]
  key_name               = aws_key_pair.ec2.id

  tags = { Name = upper("${var.identifiant}_VM_site") }
}

resource "aws_key_pair" "ec2" {
   key_name   = lower("${var.identifiant}_key")
   public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCYeVmR0L/O7EeKaqKyTe3xvmOYKd6IhRdYhW4iHjJ6ekBl8auHYwfe2n2wu6BT0fYq5JTuiRdcPBO0Iqz4PfOaPJbScJir/oG7GjMk9+DXStsEGh+09M3lacJI9Y54ldy5rmeNgSBqNi0q6KRaK5VCLG2U8TQIBnWSqPQh+g9R1z4EBuoZU7KkIsL/mbL+h4skQdWrNJixPGzWGDWpznO6+S4zLh7n486EkQ/HzTpjsZiq6UloBEQk2RqvtZRxYiw2mLiVAeJjHTd/W54ExA+WvV5Yd1pJkJCMyIEvymYfyFgygkmy6535E7a0ndJynVVmMjlr25PER91KOvDz1vIwtvaT7S7r2e5v2+XgtN4/Ylgm6rspg0kFE5KfgMeqp5YmkpT8EVItXERQqe7aW2AGN4TSIMttXTvMQR7oYiAtOW6gfx7vFdKrS2EfxFP3g47Yz0X0irjexAbiJBxfbkanuF8YQAk+wCJtJ0IJfDUQDno/bEOoB8Sp3fkZyjyw3uCK6CzEFQkZBHUaUfIawsrkQIpSUXnj8o5ebrhoM02B7kLKzrmT4Le3JEDqzqoJ3OX2Uoeb5DaXIN42UsZhehFTWks3mNZXZYfxWub1gpfBAbq+m8e2gvfr3pcpx+eRbRiD7P6WrUUKgeAw3GtYgHdB3TYRKadcUDNxRql/PlFmPQ=="
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

resource "aws_security_group_rule" "rds_from_api" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ec2.id
  cidr_blocks              = ["0.0.0.0/0"]
}

data "aws_security_group" "lb" {
  filter {
    name   = "tag:Name"
    values = ["SG_LB"]
  }
}

data "aws_security_group" "rds" {
  filter {
    name   = "tag:Name"
    values = ["GROUILLE_SG_RDS_MUTU"]
  }

  vpc_id = data.aws_vpc.selected.id
}

data "aws_lb" "lb" {
  name = "lb"
}
