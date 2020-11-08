terraform {
  required_version = ">= 0.13"
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
  description = "kubernetes name prefix to prepend to all resources (should be short, like xtz)"
  default = "xtz"
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

variable "kubernetes_pool_name" {
  type = string
  description = "when kubernetes cluster has several node pools, specify which ones to deploy the baking setup into. only effective when deploying on an external cluster with terraform_no_cluster_create"
  default = "blockchain-pool"
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

variable "signer_target_host_key" {
  type = string
  description = "ssh host key for the ssh endpoint the remote signer connects to. if you leave it empty, sshd will generate it but it may change, cutting your access to the remote signers."
  default = ""
}

variable "protocols" {
  type = list
  description = "The list of Tezos protocols currently in use, following the naming convention used in the baker/endorser binary names, for example 006-PsCARTHA. Baking and endorsing daemons will be spun up for every protocol provided in the list, which helps for seamless protocol updates"
  default = [ "006-PsCARTHA", "007-PsDELPH1" ]
  validation {
    condition     = length(sort(var.protocols)) == length(distinct(sort(var.protocols)))
    error_message = "You must pass different protocols, passing the same protocol twice is not allowed as it introduces double-baking risk."
  }
}

variable "snapshot_url" {
  type = string
  description = "url of the snapshot of type rolling to download"
  default = "https://mainnet.xtz-shots.io/rolling"
}

variable "history_mode" {
  type = string
  description = "history mode of the tezos nodes"
  default = "rolling"
}

variable "node_storage_size" {
  type = string
  description = "storage size for the nodes, in gi"
  default = "15"
}

variable "rpc_public_hostname" {
  type = string
  description = "if set, expose the rpc of the public node through a load balancer and create a certificate for the given hostname"
  default = ""
}

variable "rpc_subnet_whitelist" {
  type = list
  description = "ip address whitelisting for the public rpc. defaults to open to everyone"
  default = [ "0.0.0.0/0" ]
}

variable "monitoring_slack_url" {
  type = string
  default = ""
  description = "slack api url to send prometheus alerts to"
}

variable "lb_name" {
  type = string
  default = "tezos-baker-lb"
  description = "The name for the load balancer. It should really not be parametrizable but unique across deployments FIXME"
}
