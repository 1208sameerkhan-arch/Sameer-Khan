provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "app_server" {
  ami           = "ami-019715e0d74f695be"   # Ubuntu 20.04 x86 (us-east-2)
  instance_type = "t3.micro"
  key_name      = "Key-Mac"

  tags = {
    Name = "My-App-Server"
  }
}
