resource "google_compute_global_address" "default" {
  project      = local.tezos_baker_project_id
  name         = "baker-website-address"
  ip_version   = "IPV4"
  address_type = "EXTERNAL"
}

resource "google_compute_target_http_proxy" "http" {
  project      = local.tezos_baker_project_id
  name    = "baker-website-http-proxy"
  url_map = google_compute_url_map.urlmap.name

}

resource "google_compute_global_forwarding_rule" "http" {
  provider   = google-beta
  project      = local.tezos_baker_project_id
  name       = "baker-website-http-rule"
  target     = google_compute_target_http_proxy.http.self_link
  ip_address = google_compute_global_address.default.address
  port_range = "80"

  depends_on = [google_compute_global_address.default]

}

# ------------------------------------------------------------------------------
# IF SSL ENABLED, CREATE FORWARDING RULE AND PROXY
# ------------------------------------------------------------------------------

resource "google_compute_global_forwarding_rule" "https" {
  provider   = google-beta
  project      = local.tezos_baker_project_id
  name       = "baker-website-https-rule"
  target     = google_compute_target_https_proxy.default.self_link
  ip_address = google_compute_global_address.default.address
  port_range = "443"
  depends_on = [google_compute_global_address.default]

}

# ------------------------------------------------------------------------------
# CREATE A CORRESPONDING GOOGLE CERTIFICATE THAT WE CAN ATTACH TO THE LOAD BALANCER
# ------------------------------------------------------------------------------

resource "google_compute_target_https_proxy" "default" {
  project      = local.tezos_baker_project_id
  name    = "baker-website-https-proxy"
  url_map = google_compute_url_map.urlmap.name

  ssl_certificates = google_compute_ssl_certificate.certificate.*.self_link
}

# ------------------------------------------------------------------------------
# IF DNS ENTRY REQUESTED, CREATE A RECORD POINTING TO THE PUBLIC IP OF THE CLB
# ------------------------------------------------------------------------------

resource "google_dns_record_set" "dns" {
  project      = local.tezos_baker_project_id

  name = "${var.website}."
  type = "A"
  ttl  = 60

  managed_zone = google_dns_managed_zone.baker_dns_zone.name

  rrdatas = [google_compute_global_address.default.address]
}

# ------------------------------------------------------------------------------
# CREATE THE BACKEND BUCKET
# ------------------------------------------------------------------------------

resource "google_compute_backend_bucket" "website_backend" {
  project      = local.tezos_baker_project_id
  name        = "website-backend-bucket"
  description = "Tezos backend website"
  bucket_name = "${google_storage_bucket.website.name}"
  enable_cdn  = true
}


# ------------------------------------------------------------------------------
# CREATE THE URL MAP TO MAP PATHS TO BACKENDS
# ------------------------------------------------------------------------------

resource "google_compute_url_map" "urlmap" {
  project      = local.tezos_baker_project_id

  name        = "baker-website-url-map"
  description = "URL map for baker-website"

  default_service = google_compute_backend_bucket.website_backend.self_link

  host_rule {
    hosts        = ["*"]
    path_matcher = "all"
  }

  path_matcher {
    name            = "all"
    default_service = google_compute_backend_bucket.website_backend.self_link

  }
}


# ------------------------------------------------------------------------------
# IF SSL IS ENABLED, CREATE A SELF-SIGNED CERTIFICATE
# ------------------------------------------------------------------------------

resource "tls_self_signed_cert" "cert" {

  key_algorithm   = "RSA"
  private_key_pem = join("", tls_private_key.private_key.*.private_key_pem)

  subject {
    common_name  = var.website
    organization = "Tezos Baker"
  }

  validity_period_hours = 12

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "tls_private_key" "private_key" {
  algorithm   = "RSA"
  ecdsa_curve = "P256"
}

# ------------------------------------------------------------------------------
# CREATE A CORRESPONDING GOOGLE CERTIFICATE THAT WE CAN ATTACH TO THE LOAD BALANCER
# ------------------------------------------------------------------------------

resource "google_compute_ssl_certificate" "certificate" {
  project      = local.tezos_baker_project_id

  name_prefix = "tezos-baker-website-cert"
  description = "SSL Certificate"
  private_key = join("", tls_private_key.private_key.*.private_key_pem)
  certificate = join("", tls_self_signed_cert.cert.*.cert_pem)

  lifecycle {
    create_before_destroy = true
  }
}
