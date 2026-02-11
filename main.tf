resource "aws_instance" "api" {
  ami               = var.ami
  subnet_id         = var.subnet_id
  availability_zone = var.az
  vpc_security_group_ids = [aws_security_group.sg_api.id]
  instance_type     = "t3.micro"
  tags = { Name = upper("${var.identifiant}_${var.workspace}_VM_${var.name}") }
}

resource "aws_instance" "site" {
  ami               = var.ami
  subnet_id         = var.subnet_id
  availability_zone = var.az
  instance_type     = "t3.micro"
  vpc_security_group_ids = [aws_security_group.sg_site.id]
  tags = { Name = upper("${var.identifiant}_${var.workspace}_VM_${var.name}") }
}

resource "aws_ebs_volume" "ebs_volume" {
  for_each          = var.disks
  availability_zone = var.az
  size              = each.value

  tags = { Name = upper("${var.identifiant}_${var.workspace}_EBS_VOLUME_${var.name}") }
}

resource "aws_volume_attachment" "ebs_att" {
  for_each    = var.disks
  device_name = each.key
  volume_id   = aws_ebs_volume.ebs_volume[each.key].id
  instance_id = aws_instance.vm.id
}

