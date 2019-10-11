provider "cloudflare" {
  version = "~> 2.0"
  email   = "${var.cloudflare_email}"
  api_key = "${var.cloudflare_api_key}"
  account_id = "${var.cloudflare_account_id}"
}

resource "cloudflare_zone" "tezos_baker_zone" {
    zone = var.website
}

resource "cloudflare_record" "www" {
  zone_id  = cloudflare_zone.tezos_baker_zone.id
  name    = "www"
  value   = google_compute_global_address.default.address
  type    = "A"
  proxied = true
}

resource "cloudflare_record" "main" {
  zone_id  = cloudflare_zone.tezos_baker_zone.id
  name    = "@"
  value   = google_compute_global_address.default.address
  type    = "A"
  proxied = true
}
