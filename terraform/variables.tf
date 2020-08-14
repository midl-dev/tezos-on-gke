terraform {
  required_version = ">= 0.12"
}

variable "org_id" {
  type        = string
  description = "Organization ID."
  default = ""
}

variable "billing_account" {
  type        = string
  description = "Billing account ID."
  default = ""
}

variable "project" {
  type        = string
  default     = ""
  description = "Project ID where Terraform is authenticated to run to create additional projects. If provided, Terraform will great the GKE and Tezos cluster inside this project. If not given, Terraform will generate a new project."
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "Region in which to create the cluster, or region where the cluster exists."
}

variable "node_locations" {
  type        = list
  default     = [ "us-central1-b", "us-central1-f" ]
  description = "Zones in which to create the nodes"
}


variable "kubernetes_namespace" {
  type = string
  description = "kubernetes namespace to deploy the resource into"
  default = "tezos"
}

variable "kubernetes_name_prefix" {
  type = string
  description = "kubernetes name prefix to prepend to all resources (should be short, like DOT)"
  default = "dot"
}

variable "kubernetes_endpoint" {
  type = string
  description = "name of the kubernetes endpoint"
  default = ""
}

variable "cluster_ca_certificate" {
  type = string
  description = "kubernetes cluster certificate"
  default = ""
}

variable "cluster_name" {
  type = string
  description = "name of the kubernetes cluster"
  default = ""
}

variable "kubernetes_access_token" {
  type = string
  description = "name of the kubernetes endpoint"
  default = ""
}

variable "terraform_service_account_credentials" {
  type = string
  description = "path to terraform service account file, created following the instructions in https://cloud.google.com/community/tutorials/managing-gcp-projects-with-terraform"
  default = "~/.config/gcloud/application_default_credentials.json"
}

#
# Tezos node and baker options
# ------------------------------

variable "baking_nodes" {
  type = map
  description = "Structured data related to baking, including public key and signer configuration"
  default = {}
}

variable "tezos_network" {
  type =string
  description = "The tezos network i.e. mainnet, carthagenet..."
  default = "mainnet"
}

variable "tezos_sentry_version" {
  type =string
  description = "The tezos container version for sentry (public) nodes. Should be hard-coded to a version from https://hub.docker.com/r/tezos/tezos/tags. Not recommended to set to a rolling tag like 'mainnet', because it may break unexpectedly. Example: mainnet_06398944_20200211142914"
  default = "latest-release"
}

variable "tezos_private_version" {
  type =string
  description = "The tezos container version for private node. Should be hard-coded to a version from https://hub.docker.com/r/tezos/tezos/tags. Not recommended to set to a rolling tag like 'mainnet', because it may break unexpectedly. Example: mainnet_06398944_20200211142914"
  default = "latest-release"
}

variable "signer_target_random_hostname" {
  type = string
  description = "Random string such as 128fecf31d for the fqdn of the ssh endpoint the remote signer connects to (for example 128fec31d.mybaker.com)."
  default = "signer"
}

variable "protocol" {
  type = string
  description = "The Tezos protocol currently in use, for example 006-PsCARTHA."
  default = "006-PsCARTHA"
}

variable "protocol_short" {
  type = string
  description = "The short string describing the protocol, for example PsCARTHA."
  default = "PsCARTHA"
}

variable "full_snapshot_url" {
  type = string
  description = "url of the snapshot of type full to download"
  default = ""
}

variable "rolling_snapshot_url" {
  type = string
  description = "url of the snapshot of type rolling to download"
  default = ""
}

variable "monitoring_slack_url" {
  type = string
  default = ""
  description = "slack api url to send prometheus alerts to"
}
