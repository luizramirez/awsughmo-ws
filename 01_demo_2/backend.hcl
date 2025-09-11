bucket         = "tf-demo-state-hoch"   # pre-create or bootstrap once with CLI
key            = "envs/dev/terraform.tfstate"
region         = "us-west-1"
dynamodb_table = "tf-demo-lock"
encrypt        = true

