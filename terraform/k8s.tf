locals {
  kubernetes_variables = { "project" : module.terraform-gke-blockchain.project,
       "tezos_version": var.tezos_version,
       "tezos_network": var.tezos_network,
       "baking_nodes": var.baking_nodes,
       "kubernetes_namespace": var.kubernetes_namespace,
       "kubernetes_name_prefix": var.kubernetes_name_prefix,
       "monitoring_slack_url": var.monitoring_slack_url,
       "monitoring_smtp_server": var.monitoring_smtp_server,
       "monitoring_smtp_username": var.monitoring_smtp_username,
       "monitoring_smtp_password": var.monitoring_smtp_password,
       "monitoring_email_from": var.monitoring_email_from,
       "history_mode": var.history_mode,
       "node_storage_size": var.node_storage_size,
       "rpc_public_hostname": var.rpc_public_hostname,
       "protocols": var.protocols,
       "snapshot_url": var.snapshot_url,
       "experimental_active_standby_mode": var.experimental_active_standby_mode}
}

resource "null_resource" "push_containers" {

  triggers = {
    host = md5(module.terraform-gke-blockchain.kubernetes_endpoint)
    cluster_ca_certificate = md5(
      module.terraform-gke-blockchain.cluster_ca_certificate,
    )
  }
  provisioner "local-exec" {
    interpreter = [ "/bin/bash", "-c" ]
    command = <<EOF
set -x

build_container () {
  set -x
  cd $1
  container=$(basename $1)
  cp Dockerfile.template Dockerfile
  sed -i "s/((tezos_version))/${var.tezos_version}/" Dockerfile
  cat << EOY > cloudbuild.yaml
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', "gcr.io/${module.terraform-gke-blockchain.project}/$container:${var.kubernetes_namespace}-latest", '.']
images: ["gcr.io/${module.terraform-gke-blockchain.project}/$container:${var.kubernetes_namespace}-latest"]
EOY
  gcloud builds submit --project ${module.terraform-gke-blockchain.project} --config cloudbuild.yaml .
  rm -v Dockerfile
  rm cloudbuild.yaml
}
export -f build_container
find ${path.module}/../docker -mindepth 1 -maxdepth 1 -type d -exec bash -c 'build_container "$0"' {} \; -printf '%f\n'
EOF
  }
}

# Provision IP for signer forwarder endpoint if there is at least one occurence of "authorized_signers" data in the bakers map
resource "google_compute_address" "signer_forwarder_target" {
  # it should not be more than one
  count = length(lookup((merge(merge(values(merge(merge(values(var.baking_nodes)...),{}))...),{})), "authorized_signers", [])) > 0 ? 1 : 0
  name    = "${var.kubernetes_name_prefix}-signer-target"
  region  = module.terraform-gke-blockchain.location
  project = module.terraform-gke-blockchain.project
}

resource "kubernetes_namespace" "tezos_namespace" {
  metadata {
    name = var.kubernetes_namespace
  }
  depends_on = [ module.terraform-gke-blockchain ]
}

resource "kubernetes_secret" "signer_secret" {
  metadata {
    name = "signer-secret"
    namespace = var.kubernetes_namespace
  }
  data = {
    "SIGNER_DATA": jsonencode({"baking_nodes":var.baking_nodes}),
    "SIGNER_TARGET_HOST_KEY": jsonencode(var.signer_target_host_key)
  }

  depends_on = [ kubernetes_namespace.tezos_namespace ]
}

resource "null_resource" "apply" {
  provisioner "local-exec" {

    interpreter = [ "/bin/bash", "-c" ]
    command = <<EOF
set -e
set -x
gcloud container clusters get-credentials "${module.terraform-gke-blockchain.name}" --region="${module.terraform-gke-blockchain.location}" --project="${module.terraform-gke-blockchain.project}"

rm -rvf ${path.module}/k8s-${var.kubernetes_namespace}
mkdir -p ${path.module}/k8s-${var.kubernetes_namespace}
cp -rv ${path.module}/../k8s/*base* ${path.module}/k8s-${var.kubernetes_namespace}
mkdir -pv ${path.module}/k8s-${var.kubernetes_namespace}/tezos-alertmanager
cd ${abspath(path.module)}/k8s-${var.kubernetes_namespace}
cat <<EOK > kustomization.yaml
${templatefile("${path.module}/../k8s/kustomization.yaml.tmpl", local.kubernetes_variables)}
EOK

mkdir -pv tezos-common
cat <<EOK > tezos-common/kustomization.yaml
${templatefile("${path.module}/../k8s/tezos-common-tmpl/kustomization.yaml.tmpl", local.kubernetes_variables)}
EOK
mkdir -pv tezos-public-rpc
cat <<EOK > tezos-public-rpc/kustomization.yaml
${templatefile("${path.module}/../k8s/tezos-public-rpc-tmpl/kustomization.yaml.tmpl", local.kubernetes_variables)}
EOK
cat <<EOP > tezos-public-rpc/static-ip-patch.yaml
${templatefile("${path.module}/../k8s/tezos-public-rpc-tmpl/static-ip-patch.yaml.tmpl", merge(local.kubernetes_variables, { "nodename": keys(var.baking_nodes)[0] }))}
EOP

cat <<EOK > tezos-alertmanager/kustomization.yaml
${templatefile("${path.module}/../k8s/tezos-alertmanager-tmpl/kustomization.yaml.tmpl", local.kubernetes_variables)}
EOK
cat <<'EOMP' > tezos-alertmanager/tezos_alertmanager.yaml
${templatefile("${path.module}/../k8s/tezos-alertmanager-tmpl/tezos_alertmanager.yaml.tmpl",
  local.kubernetes_variables)}
EOMP

%{ for nodename in keys(var.baking_nodes) }
mkdir -pv tezos-node-${nodename}
cat <<EOK > tezos-node-${nodename}/kustomization.yaml
${templatefile("${path.module}/../k8s/tezos-node-tmpl/kustomization.yaml.tmpl", merge(local.kubernetes_variables, { "nodename": nodename, "protocols": var.protocols }))}
EOK
# the two below are necessary because kustomize embedded in the most recent version of kubectl does not apply prefix to volume class
cat <<EOPVN > tezos-node-${nodename}/prefixedpvnode.yaml
${templatefile("${path.module}/../k8s/tezos-node-tmpl/prefixedpvnode.yaml.tmpl", local.kubernetes_variables)}
EOPVN
cat <<EONPN > tezos-node-${nodename}/replicas.yaml
${templatefile("${path.module}/../k8s/tezos-node-tmpl/replicas.yaml.tmpl", local.kubernetes_variables)}
EONPN
cat <<EONPN > tezos-node-${nodename}/nodepool.yaml
${templatefile("${path.module}/../k8s/tezos-node-tmpl/nodepool.yaml.tmpl", {"kubernetes_pool_name": var.kubernetes_pool_name})}
EONPN
cat <<EOSP > tezos-node-${nodename}/service-patch.yaml
${templatefile("${path.module}/../k8s/tezos-node-tmpl/service-patch.yaml.tmpl", local.kubernetes_variables)}
EOSP

%{ for protocol in var.protocols }
cat <<EOBEP > tezos-node-${nodename}/baker_endorser_process_patch_${protocol}.yaml
${templatefile("${path.module}/../k8s/tezos-node-tmpl/baker_endorser_process_patch.yaml.tmpl", {"bakers": keys(var.baking_nodes[nodename]), "protocol": protocol})}
EOBEP
%{ endfor }

%{ for baker_name in keys(var.baking_nodes[nodename]) }

%{ if ! contains(keys(var.baking_nodes[nodename][baker_name]), "insecure_private_baking_key") }

# instantiate a load balancer since the private key is in a cold wallet
mkdir -pv tezos-remote-signer-loadbalancer-${baker_name}
cat <<EOK > tezos-remote-signer-loadbalancer-${baker_name}/kustomization.yaml
${templatefile("${path.module}/../k8s/tezos-remote-signer-loadbalancer-tmpl/kustomization.yaml.tmpl", merge(local.kubernetes_variables, { "baker_name": baker_name, "nodename" : nodename, authorized_signers = var.baking_nodes[nodename][baker_name]["authorized_signers"]} ))}
EOK

%{ for signerindex, signer in var.baking_nodes[nodename][baker_name]["authorized_signers"] }
# configure the forwarder for this remote signer (network policies, service monitoring)
cat <<EORSP > tezos-remote-signer-loadbalancer-${baker_name}/remote_signer_patch_${signerindex}.yaml
${templatefile("${path.module}/../k8s/tezos-remote-signer-loadbalancer-tmpl/remote_signer_patch.yaml.tmpl",
  { "signerport": signer["signer_port"],
    "signername": format("%s-%s", baker_name, signerindex),
    "signer_forwarder_target_address" : length(google_compute_address.signer_forwarder_target) > 0 ? google_compute_address.signer_forwarder_target[0].address : "",
    "signer_pubkey": signer["ssh_pubkey"],
    "tunnel_endpoint_port": signer["tunnel_endpoint_port"]})}
EORSP

mkdir -pv tezos-remote-signer-loadbalancer-${baker_name}-${signerindex}
cat <<EOMP > tezos-remote-signer-loadbalancer-${baker_name}-${signerindex}/remote_signer_monitor_and_networkpolicy.yaml
${templatefile("${path.module}/../k8s/tezos-remote-signer-loadbalancer-tmpl/remote_signer_monitor_and_networkpolicy.yaml.tmpl",
  merge(local.kubernetes_variables, { 
    "baker_name": baker_name,
    "nodename" : nodename,
    "tunnel_endpoint_port": signer["tunnel_endpoint_port"],
    "signerport": signer["signer_port"],
    "signername": format("%s-%s", baker_name, signerindex)} ))}
EOMP

cat <<EOK > tezos-remote-signer-loadbalancer-${baker_name}-${signerindex}/kustomization.yaml
namePrefix: ${var.kubernetes_name_prefix}-
namespace: ${var.kubernetes_namespace}
resources:
- remote_signer_monitor_and_networkpolicy.yaml
commonLabels:
  app: tezos-remote-signer-forwarder-${baker_name}
EOK
%{ endfor}

cat <<EONPN > tezos-remote-signer-loadbalancer-${baker_name}/nodepool.yaml
${templatefile("${path.module}/../k8s/tezos-remote-signer-loadbalancer-tmpl/nodepool.yaml.tmpl", {"kubernetes_pool_name": var.kubernetes_pool_name})}
EONPN
%{ endif }

%{ if contains(keys(var.baking_nodes[nodename][baker_name]), "payout_config") }
mkdir -pv payout-${baker_name}
cat <<EOK > payout-${baker_name}/kustomization.yaml
${templatefile("${path.module}/../k8s/payout-tmpl/kustomization.yaml.tmpl", 
  merge(var.baking_nodes[nodename][baker_name]["payout_config"], {
  "project": var.project,
  "baker_name": baker_name,
  "region": module.terraform-gke-blockchain.location,
  "report_bucket_url": google_storage_bucket.trd_report_bucket[baker_name].url
  "kubernetes_name_prefix": var.kubernetes_name_prefix,
  "kubernetes_namespace": var.kubernetes_namespace} ))}
EOK
cat <<EOC > payout-${baker_name}/config.yaml
${yamlencode({
version: "1.0",
baking_address: var.baking_nodes[nodename][baker_name]["public_baking_key_hash"],
payment_address: var.baking_nodes[nodename][baker_name]["payout_config"]["payment_address"],
rewards_type: var.baking_nodes[nodename][baker_name]["payout_config"]["rewards_type"],
service_fee: var.baking_nodes[nodename][baker_name]["payout_config"]["service_fee"],
reactivate_zeroed: true,
delegator_pays_xfer_fee: true,
delegator_pays_ra_fee: true,
rules_map: try(var.baking_nodes[nodename][baker_name]["payout_config"]["rules_map"], {}),
})}
EOC
cat <<EOPN > payout-${baker_name}/nodepool.yaml
${templatefile("${path.module}/../k8s/payout-tmpl/nodepool.yaml.tmpl", {"kubernetes_payout_pool_name": var.kubernetes_payout_pool_name})}
EOPN
cat <<EOA > payout-${baker_name}/trd-args.yaml
${templatefile("${path.module}/../k8s/payout-tmpl/trd-args.yaml.tmpl", 
  merge(var.baking_nodes[nodename][baker_name]["payout_config"], {
  "baker_name": baker_name,
  "kubernetes_name_prefix": var.kubernetes_name_prefix })) }
EOA
cat <<EOPC > payout-${baker_name}/crontime.yaml
${templatefile("${path.module}/../k8s/payout-tmpl/crontime.yaml.tmpl", {"schedule": var.baking_nodes[nodename][baker_name]["payout_config"]["schedule"]})}
EOPC
echo Now writing to payout-${baker_name}/serviceaccountannotate.yaml
cat <<EONPN > payout-${baker_name}/serviceaccountannotate.yaml
${templatefile("${path.module}/../k8s/payout-tmpl/serviceaccountannotate.yaml.tmpl", local.kubernetes_variables)}
EONPN
%{ endif }

%{ endfor}

%{ endfor}

kubectl apply -k .
cd ${abspath(path.module)}
rm -rvf ${abspath(path.module)}/k8s-${var.kubernetes_namespace}
EOF

  }
  depends_on = [ null_resource.push_containers, kubernetes_namespace.tezos_namespace ]
}

#############################
# Public RPC endpoint
#############################

# Provision IP for public rpc endpoint
resource "google_compute_global_address" "public_rpc_ip" {
  count = var.rpc_public_hostname == "" ? 0 : 1
  name    = "${var.kubernetes_name_prefix}-tezos-rpc-ip"
  project = module.terraform-gke-blockchain.project
}

resource "google_compute_security_policy" "public_rpc_filter" {
  count = var.rpc_public_hostname == "" ? 0 : 1
  name = "${var.kubernetes_name_prefix}-tezos-rpc-filter"
  project = module.terraform-gke-blockchain.project

  dynamic "rule" {
    for_each = [ for index, subnet in concat(var.rpc_subnet_whitelist,
      #Google ranges - for their inernal load balancer monitoring
      ["35.191.0.0/16", "130.211.0.0/22"]) : { "index": index, "subnet": subnet } ]

    content {
      action   = "allow"
      priority = 1000+rule.value.index
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = [rule.value.subnet]
        }
      }
      description = "Allow access to whitelisted ips and google monitoring ranges"
    }
  }

  rule {
    action   = "deny(403)"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "default rule, deny"
  }

}

#############################
# Reward Buckets
#############################

# we create buckets for every baker (even if they are not public)
# because it's simpler

resource "google_service_account" "payout_report_uploader" {
  account_id   = "${var.kubernetes_name_prefix}-payout-report-uploader"
  display_name = "Payout report uploader for ${var.kubernetes_name_prefix}"
  project = module.terraform-gke-blockchain.project 
}

# based on workload identity docs
# https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity
resource "google_service_account_iam_binding" "payout_report_uploader_binding" {
  service_account_id = google_service_account.payout_report_uploader.name
  role               = "roles/iam.workloadIdentityUser"

  members = [ for k in toset(keys(merge(merge(values(var.baking_nodes)...),{}))) :
    "serviceAccount:${module.terraform-gke-blockchain.project}.svc.id.goog[${var.kubernetes_namespace}/${var.kubernetes_name_prefix}-trd-report-uploader-${k}]"
  ]
}
resource "random_id" "rnd_bucket" {
  for_each = toset(keys(merge(merge(values(var.baking_nodes)...),{})))
  byte_length = 4
}
resource "google_storage_bucket" "trd_report_bucket" {
  for_each = toset(keys(merge(merge(values(var.baking_nodes)...),{})))
  name     = "${var.kubernetes_name_prefix}-baker-payout-${each.key}-${random_id.rnd_bucket[each.key].hex}"
  project = module.terraform-gke-blockchain.project

  force_destroy = true
}

resource "google_storage_bucket_iam_member" "member" {
  for_each = toset(keys(merge(merge(values(var.baking_nodes)...),{})))
  bucket = google_storage_bucket.trd_report_bucket[each.key].name
  role        = "roles/storage.objectAdmin"
  member      = "serviceAccount:${google_service_account.payout_report_uploader.email}"
}

resource "google_storage_bucket_iam_member" "make_public" {
  for_each = toset(keys(merge(merge(values(var.baking_nodes)...),{})))
  bucket = google_storage_bucket.trd_report_bucket[each.key].name
  role        = "roles/storage.objectViewer"
  member      = "allUsers"
}
