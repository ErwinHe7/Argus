output "resource_identifiers" {
  description = "Explicit nonsecret allowlist for a future release; widget secrets remain only in protected state."
  value = {
    workers = {
      for key, worker in cloudflare_worker.identities : key => { id = worker.id, name = worker.name }
    }
    pages = {
      for key, page in cloudflare_pages_project.shells : key => { id = page.id, name = page.name }
    }
    kv_namespaces = {
      for key, namespace in cloudflare_workers_kv_namespace.empty : key => { id = namespace.id, title = namespace.title }
    }
    r2_buckets = {
      for key, bucket in cloudflare_r2_bucket.private : key => { id = bucket.id, name = bucket.name }
    }
    queues = {
      for key, queue in cloudflare_queue.paused : key => { id = queue.queue_id, name = queue.queue_name }
    }
    turnstile = {
      for key, widget in cloudflare_turnstile_widget.unused : key => { sitekey = widget.sitekey, name = widget.name }
    }
  }
}

# Internal module output used by root-wiring mock tests. This is configuration
# evidence only; it does not attest that a hosted resource has never been used.
output "provisioning_contract" {
  description = "Allowlisted nonsecret resource attributes for testing the actual environment root wiring."
  value = {
    workers = {
      for key, worker in cloudflare_worker.identities : key => {
        account_id        = worker.account_id
        subdomain_enabled = worker.subdomain.enabled
        previews_enabled  = worker.subdomain.previews_enabled
        tail_consumers    = worker.tail_consumers
      }
    }
    pages = {
      for key, page in cloudflare_pages_project.shells : key => {
        account_id    = page.account_id
        source_absent = page.source == null
      }
    }
    kv_namespaces = {
      for key, namespace in cloudflare_workers_kv_namespace.empty : key => { account_id = namespace.account_id }
    }
    r2_buckets = {
      for key, bucket in cloudflare_r2_bucket.private : key => { account_id = bucket.account_id }
    }
    queues = {
      for key, queue in cloudflare_queue.paused : key => {
        account_id            = queue.account_id
        delivery_paused       = queue.settings.delivery_paused
        consumers_total_count = queue.consumers_total_count
        producers_total_count = queue.producers_total_count
      }
    }
    turnstile = {
      for key, widget in cloudflare_turnstile_widget.unused : key => {
        account_id      = widget.account_id
        clearance_level = widget.clearance_level
      }
    }
  }
}
