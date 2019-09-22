terraform {
  required_version = ">= 0.12"
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "Region in which to create the cluster."
}

variable "node_locations" {
  type  = list
  default = [ "us-central1-b", "us-central1-f" ]
  description = "list of locations within the regions where to deploy the nodes"
}

variable "project" {
  type        = string
  default     = ""
  description = "Project ID where Terraform is authenticated to run to create additional projects. If provided, Terraform will great the GKE and Tezos cluster inside this project. If not given, Terraform will generate a new project."
}

variable "billing_account" {
  type        = string
  description = "Billing account ID."
}

variable "kubernetes_instance_type" {
  type        = string
  default     = "n1-standard-2"
  description = "Instance type to use for the nodes."
}

variable "service_account_iam_roles" {
  type = list(string)
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/storage.objectViewer"
  ]
  description = "List of IAM roles to assign to the service account."
}

variable "project_services" {
  type = list(string)
  default = [
    "cloudresourcemanager.googleapis.com",
    "container.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ]
  description = "List of services to enable on the project."
}
#
# Kubernetes options
# ------------------------------

variable "kubernetes_nodes_per_zone" {
  type        = number
  default     = 1
  description = "Number of nodes to deploy in each zone of the Kubernetes cluster. For example, if there are 4 zones in the region and num_nodes_per_zone is 2, 8 total nodes will be created."
}

variable "kubernetes_daily_maintenance_window" {
  type        = string
  default     = "06:00"
  description = "Maintenance window for GKE."
}

variable "kubernetes_logging_service" {
  type        = string
  default     = "logging.googleapis.com/kubernetes"
  description = "Name of the logging service to use. By default this uses the new Stackdriver GKE beta."
}

variable "kubernetes_monitoring_service" {
  type        = string
  default     = "monitoring.googleapis.com/kubernetes"
  description = "Name of the monitoring service to use. By default this uses the new Stackdriver GKE beta."
}

variable "kubernetes_network_ipv4_cidr" {
  type        = string
  default     = "10.0.96.0/22"
  description = "IP CIDR block for the subnetwork. This must be at least /22 and cannot overlap with any other IP CIDR ranges."
}

variable "kubernetes_pods_ipv4_cidr" {
  type        = string
  default     = "10.0.92.0/22"
  description = "IP CIDR block for pods. This must be at least /22 and cannot overlap with any other IP CIDR ranges."
}

variable "kubernetes_services_ipv4_cidr" {
  type        = string
  default     = "10.0.88.0/22"
  description = "IP CIDR block for services. This must be at least /22 and cannot overlap with any other IP CIDR ranges."
}

variable "kubernetes_masters_ipv4_cidr" {
  type        = string
  default     = "10.0.82.0/28"
  description = "IP CIDR block for the Kubernetes master nodes. This must be exactly /28 and cannot overlap with any other IP CIDR ranges."
}

variable "kubernetes_master_authorized_networks" {
  type = list(object({
    display_name = string
    cidr_block   = string
  }))

  default = [
    {
      display_name = "Anyone"
      cidr_block   = "0.0.0.0/0"
    },
  ]

  description = "List of CIDR blocks to allow access to the master's API endpoint. This is specified as a slice of objects, where each object has a display_name and cidr_block attribute. The default behavior is to allow anyone (0.0.0.0/0) access to the endpoint. You should restrict access to external IPs that need to access the cluster."
}

variable "org_id" {
  type        = string
  description = "Organization ID."
}

variable "public_baking_key" {
  type  = string
  description = "The public baker tz1 public key that delegators delegate to"
}

variable "snapshot_url" {
  type = string
  description = "The public URL where to download the tezos blockchain snapshot for quicker sync of the public nodes"
}

variable "archive_url" {
  type = string
  description = "The public URL where to download the full historical tezos blockchain for quicker sync of the private node"
}

variable "authorized_signer_key_a" {
  type = string
  description = "Public key of the first remote signer"
}

variable "authorized_signer_key_b" {
  type = string
  description = "Public key of the first remote signer"
}

variable "hot_wallet_public_key" {
  type = string
  description = "The public key of the hot wallet or payout wallet (where rewards come from)"
}

variable "hot_wallet_private_key" {
  type = string
  description = "The private key of the hot wallet or payout wallet (where rewards come from)"
}

variable "tezos_network" {
  type =string
  description = "The tezos network (alphanet and mainnet supported)"
}

variable "payout_delay" {
  type =string
  description = "Number of cycles to delay the payout compared to PRESERVED_CYCLES (can be negatives to pay out in advance)"
}
