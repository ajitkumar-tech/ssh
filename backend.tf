terraform {
  backend "s3" { 
    bucket = "vpc-endpoint"
    key    = "statefile/terraform.tfstate" 
    region = "ap-south-1"
    
  }
}
