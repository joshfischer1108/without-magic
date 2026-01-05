data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "default_subnet" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = [var.availability_zone]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

data "aws_ssm_parameter" "ubuntu_24_04_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "sandbox_key" {
  key_name   = var.key_pair_name
  public_key = file(var.public_key_path)
}

resource "aws_security_group" "sandbox_sg" {
  name        = "sandbox-sg"
  description = "Allow SSH and HTTP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ec2_cidr_blocks]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.ec2_cidr_blocks]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "sandbox" {
  ami                    = data.aws_ssm_parameter.ubuntu_24_04_ami.value
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnet.default_subnet.id
  vpc_security_group_ids = [aws_security_group.sandbox_sg.id]
  key_name               = aws_key_pair.sandbox_key.key_name

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    fqdn = var.sandbox_fqdn
  })

  tags = {
    Name = "sandbox-ec2"
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
}

resource "aws_eip_association" "sandbox_assoc" {
  count         = var.sandbox_eip_allocation_id != "" ? 1 : 0
  instance_id   = aws_instance.sandbox.id
  allocation_id = var.sandbox_eip_allocation_id
}
