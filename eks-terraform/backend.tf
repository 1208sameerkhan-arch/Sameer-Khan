terraform {
  backend "s3" {
    bucket         = "sameer-terraform-state-bucket-123"
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}
