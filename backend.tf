terraform {
  backend "s3" { 
    bucket = "my-terraform-rt"
    key    = "statefile/terraform.tfstate" 
    region = "us-east-1"
    
  }
}
