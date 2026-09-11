# The canonical private bootstrap working directory starts with local state.
# The CLI stages backend.remote.tf.template here only during verified migration.
terraform {
  backend "local" {}
}
