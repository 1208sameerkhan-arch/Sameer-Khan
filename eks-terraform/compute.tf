resource "aws_instance" "web" {
  ami           = "ami-0f58b397bc5c1f2e8" # Amazon Linux 2 (ap-south-1)
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "sameer-ec2"
  }
}
