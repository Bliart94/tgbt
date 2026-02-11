data "aws_vpc" "this" {
  filter {
    name   = "tag:Name"
    values = ["VPC"]
  }
}

resource "aws_subnet" "this" {
  vpc_id            = data.aws_vpc.this.id
  cidr_block        = local.address_space
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = { Name = upper("${var.identifiant}_${terraform.workspace}_SUBNET") }
}
