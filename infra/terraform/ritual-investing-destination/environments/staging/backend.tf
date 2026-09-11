terraform {
  backend "s3" {
    bucket = "ritual-investing-terraform-state-staging"
    key    = "workloads/terraform.tfstate"
    region = "auto"

    skip_region_validation = true
  }
}
