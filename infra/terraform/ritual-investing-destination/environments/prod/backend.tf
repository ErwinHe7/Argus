terraform {
  backend "s3" {
    bucket = "ritual-investing-terraform-state-prod"
    key    = "workloads/terraform.tfstate"
    region = "auto"

    skip_region_validation = true
  }
}
