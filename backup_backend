terraform {
  backend "s3" {
    bucket         = "sameer-terraform-state-bucket-123"
    key            = "eks/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "sameer-test-eks"
    encrypt        = true
  }
}
