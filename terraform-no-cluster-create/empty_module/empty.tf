# An empty module.
# We do not want cluster creation to take place, so this is a placeholder for the module that creates a cluster.

variable "project" {
  type = "string"
  description = "project name"
  default = ""
}

variable "region" {
  type = "string"
  description = "the region where the cluster exists"
}

output "name" {
  value = ""
}

output "kubernetes_endpoint" {
  value = ""
}

output "cluster_ca_certificate" {
  value = ""
}

output "location" {
  value = var.region
}

output "project" {
  value = var.project
}
