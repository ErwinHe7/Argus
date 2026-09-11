output "state_buckets" {
  description = "Nonsecret destination state bucket identifiers."
  value = {
    for environment, bucket in cloudflare_r2_bucket.state : environment => {
      id         = bucket.id
      account_id = bucket.account_id
      name       = bucket.name
    }
  }
}
