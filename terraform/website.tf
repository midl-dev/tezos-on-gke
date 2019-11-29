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

resource "random_string" "no_proxy_hostname" {
  length = 16
  special = false
  upper = false
}

resource "google_compute_managed_ssl_certificate" "default" {
  provider = "google-beta"
  project      = local.tezos_baker_project_id

  name = "baker-website-cert"

  managed {
    domains = ["${random_string.no_proxy_hostname.result}.${var.website}."]
  }
}
# ------------------------------------------------------------------------------
# CREATE A CORRESPONDING GOOGLE CERTIFICATE THAT WE CAN ATTACH TO THE LOAD BALANCER
# ------------------------------------------------------------------------------

resource "google_compute_target_https_proxy" "default" {
  provider = "google-beta"
  project      = local.tezos_baker_project_id
  name    = "baker-website-https-proxy"
  url_map = google_compute_url_map.urlmap.name

  ssl_certificates = [ google_compute_managed_ssl_certificate.default.self_link ]
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
