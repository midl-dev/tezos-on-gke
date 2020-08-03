locals {
  # TODO : check whether there is any forwarder pubkey
  remote_signer_in_use = true
  kubernetes_variables = { "project" : module.terraform-gke-blockchain.project,
       "tezos_private_version": var.tezos_private_version,
       "tezos_network": var.tezos_network,
       "protocol": var.protocol,
       "protocol_short": var.protocol_short,
       "baking_nodes": var.baking_nodes,
       "baking_nodes_json": jsonencode(var.baking_nodes),
       "kubernetes_namespace": var.kubernetes_namespace,
       "kubernetes_name_prefix": var.kubernetes_name_prefix}
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
  sed -i "s/((tezos_sentry_version))/${var.tezos_sentry_version}/" Dockerfile
  sed -i "s/((tezos_private_version))/${var.tezos_private_version}/" Dockerfile
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

# Provision IP
resource "google_compute_address" "signer_forwarder_target" {
  count = local.remote_signer_in_use ? 1 : 0
  name    = "tezos-baker-lb"
  region  = module.terraform-gke-blockchain.location
  project = module.terraform-gke-blockchain.project
}

resource "kubernetes_namespace" "tezos_namespace" {
  metadata {
    name = var.kubernetes_namespace
  }
  depends_on = [ module.terraform-gke-blockchain ]
}


resource "null_resource" "apply" {
  provisioner "local-exec" {

    interpreter = [ "/bin/bash", "-c" ]
    command = <<EOF
set -e
set -x
gcloud container clusters get-credentials "${module.terraform-gke-blockchain.name}" --region="${module.terraform-gke-blockchain.location}" --project="${module.terraform-gke-blockchain.project}"

mkdir -p ${path.module}/k8s-${var.kubernetes_namespace}
cp -rv ${path.module}/../k8s/*base* ${path.module}/k8s-${var.kubernetes_namespace}
cd ${abspath(path.module)}/k8s-${var.kubernetes_namespace}
cat <<EOK > kustomization.yaml
${templatefile("${path.module}/../k8s/kustomization.yaml.tmpl", local.kubernetes_variables)}
EOK

mkdir -pv tezos-public-node
cat <<EOK > tezos-public-node/kustomization.yaml
${templatefile("${path.module}/../k8s/tezos-public-node-tmpl/kustomization.yaml.tmpl", local.kubernetes_variables)}
EOK
cat <<EOLBP > tezos-public-node/loadbalancerpatch.yaml
${templatefile("${path.module}/../k8s/tezos-public-node-tmpl/loadbalancerpatch.yaml.tmpl",
   { "signer_forwarder_target_address" : length(google_compute_address.signer_forwarder_target) > 0 ? google_compute_address.signer_forwarder_target[0].address : "" })}
EOLBP

%{ for nodename in keys(var.baking_nodes) }
mkdir -pv tezos-private-node-${nodename}
cat <<EOK > tezos-private-node-${nodename}/kustomization.yaml
${templatefile("${path.module}/../k8s/tezos-private-node-tmpl/kustomization.yaml.tmpl", merge(local.kubernetes_variables, { "nodename": nodename }))}
EOK
cat <<EORPP > tezos-private-node-${nodename}/regionalpvpatch.yaml
${templatefile("${path.module}/../k8s/tezos-private-node-tmpl/regionalpvpatch.yaml.tmpl",
   { "regional_pd_zones" : join(", ", var.node_locations),
     "kubernetes_name_prefix": var.kubernetes_name_prefix})}
EORPP
# the two below are necessary because kustomize embedded in the most recent version of kubectl does not apply prefix to volume class
cat <<EOPVN > tezos-private-node-${nodename}/prefixedpvnode.yaml
${templatefile("${path.module}/../k8s/tezos-private-node-tmpl/prefixedpvnode.yaml.tmpl", {"kubernetes_name_prefix": var.kubernetes_name_prefix})}
EOPVN
cat <<EOPVC > tezos-private-node-${nodename}/prefixedpvclient.yaml
${templatefile("${path.module}/../k8s/tezos-private-node-tmpl/prefixedpvclient.yaml.tmpl", {"kubernetes_name_prefix": var.kubernetes_name_prefix})}
EOPVC

%{ for custname in keys(var.baking_nodes[nodename]) }

cat <<EOBEP > tezos-private-node-${nodename}/baker_endorser_process_patch_${custname}.yaml
${templatefile("${path.module}/../k8s/tezos-private-node-tmpl/baker_endorser_process_patch.yaml.tmpl", {"custname": custname})}
EOBEP

mkdir -pv tezos-remote-signer-loadbalancer-${custname}
cat <<EOK > tezos-remote-signer-loadbalancer-${custname}/kustomization.yaml
${templatefile("${path.module}/../k8s/tezos-remote-signer-loadbalancer-tmpl/kustomization.yaml.tmpl", merge(local.kubernetes_variables, { "custname": custname, "nodename" : nodename} ))}
EOK
%{ endfor}

%{ endfor}

kubectl apply -k .
cd ${abspath(path.module)}
rm -rvf ${abspath(path.module)}/k8s-${var.kubernetes_namespace}
EOF

  }
  depends_on = [ null_resource.push_containers, kubernetes_namespace.tezos_namespace ]
}
