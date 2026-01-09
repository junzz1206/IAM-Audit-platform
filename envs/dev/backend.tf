terraform {
  backend "s3" {
    bucket         = "terraform-rockyvickyeasyfeezy"
    key            = "envs/dev/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}