provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "app_server" {
  ami           = "ami-0b6c6ebed2801a5cb"   # Ubuntu 20.04 x86 (us-east-1)
  instance_type = "t3.micro"
  key_name      = "gaurav"

  tags = {
    Name = "My-App-Server"
  }
}
