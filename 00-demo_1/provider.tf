# Configure the AWS Provider
provider "aws" {
  region = "us-west-1"
  default_tags {
    tags = {
      Stack = "AWSUGHMO"
    }
  }
  #access_key = "my-access-key"
  #secret_key = "my-secret-key"
}
