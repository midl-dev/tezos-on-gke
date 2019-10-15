# we need cloudflare for http to https redirect.
# doing it with google would require a nginx service to
# perform the redirect.

provider "cloudflare" {
  version = "~> 2.0"
  email   = "${var.cloudflare_email}"
  api_key = "${var.cloudflare_api_key}"
  account_id = "${var.cloudflare_account_id}"
}

resource "cloudflare_zone" "tezos_baker_zone" {
  zone = var.website
}

resource "cloudflare_zone_settings_override" "example-com-settings" {
  zone_id  = cloudflare_zone.tezos_baker_zone.id

  settings {
    tls_1_3 = "on"
    automatic_https_rewrites = "on"
    always_use_https = "on"
    ssl = "strict"
  }
}

resource "cloudflare_record" "www" {
  zone_id  = cloudflare_zone.tezos_baker_zone.id
  name    = "www"
  value   = google_compute_global_address.default.address
  type    = "A"
  proxied = true
}

resource "cloudflare_record" "no_proxy" {
  # Google cloud wants valid dns resolution before issuing the certificate.
  # If cloudflare is used as DNS, this won't work with the true website name
  # since it resolves to cloudflare proxy.
  # Instead, we create a special random "no proxy" record
  # so the certificate is created and renewed over time
  # and we can use cloudflare "strict" mode.
  # There is an apparent contradiction because the actual website
  # does not have this exact name, but cloudflare hits the
  # ip address directly anyway so it does not matter.
  zone_id  = cloudflare_zone.tezos_baker_zone.id
  name    = random_string.no_proxy_hostname.result
  value   = google_compute_global_address.default.address
  type    = "A"
  proxied = false
}

resource "cloudflare_record" "main" {
  zone_id  = cloudflare_zone.tezos_baker_zone.id
  name    = "@"
  value   = google_compute_global_address.default.address
  type    = "A"
  proxied = true
}

# the forwarders ssh target. This one should not be proxied.
resource "cloudflare_record" "forwarder_target_dns" {
  zone_id  = cloudflare_zone.tezos_baker_zone.id
  name = var.signer_target_random_hostname
  type = "A"
  ttl  = 120
  proxied = false

  value = google_compute_address.signer_forwarder_target.address
}

resource "cloudflare_record" "mx1" {
  zone_id  = cloudflare_zone.tezos_baker_zone.id
  name    = "@"
  value   = var.dns_mx_record_1
  type    = "MX"
  proxied = false
}

resource "cloudflare_record" "mx2" {
  zone_id  = cloudflare_zone.tezos_baker_zone.id
  name    = "@"
  value   = var.dns_mx_record_2
  type    = "MX"
  proxied = false
}

resource "cloudflare_record" "spf" {
  zone_id  = cloudflare_zone.tezos_baker_zone.id
  name    = "@"
  value   = var.dns_spf_record
  type    = "TXT"
  proxied = false
}

