bucket = "ritual-investing-terraform-state-staging"
key    = "ritual-investing/staging/terraform.tfstate"
region = "auto"

encrypt                       = true
use_lockfile                  = true
use_path_style                = true
skip_credentials_validation  = true
skip_region_validation       = true
skip_requesting_account_id   = true
skip_metadata_api_check      = true
skip_s3_checksum             = true
