terraform {
  backend "s3" {
    bucket         = "flowmeter-terraform-state"
    key            = "prod/terraform.tfstate"  # e.g., "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "flowmeter-terraform-state-lock"
    encrypt        = true
  }
}
