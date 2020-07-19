resource "null_resource" "push_containers" {

  triggers = {
    host = md5(module.terraform-gke-blockchain.kubernetes_endpoint)
    cluster_ca_certificate = md5(
      module.terraform-gke-blockchain.cluster_ca_certificate,
    )
  }
  provisioner "local-exec" {
    command = <<EOF


find ${path.module}/../docker -mindepth 1 -maxdepth 1 -type d  -printf '%f\n'| while read container; do
  
  pushd ${path.module}/../docker/$container
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
  popd
done
EOF
  }
}

# Provision IP
resource "google_compute_address" "signer_forwarder_target" {
  count = var.insecure_private_baking_key == "" ? 1 : 0
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

    command = <<EOF
set -e
set -x
gcloud container clusters get-credentials "${module.terraform-gke-blockchain.name}" --region="${module.terraform-gke-blockchain.location}" --project="${module.terraform-gke-blockchain.project}"

mkdir -p ${path.module}/k8s-${var.kubernetes_namespace}
cp -v ${path.module}/../k8s/*yaml* ${path.module}/k8s-${var.kubernetes_namespace}
pushd ${path.module}/k8s-${var.kubernetes_namespace}
cat <<EOK > kustomization.yaml
${templatefile("${path.module}/../k8s/kustomization.yaml.tmpl",
     { "project" : module.terraform-gke-blockchain.project,
       "public_baking_key": var.public_baking_key,
       "insecure_private_baking_key": var.insecure_private_baking_key,
       "remote_signer_in_use": var.insecure_private_baking_key == "" ? "true" : "false",
       "tezos_private_version": var.tezos_private_version,
       "tezos_network": var.tezos_network,
       "protocol": var.protocol,
       "protocol_short": var.protocol_short,
       "authorized_signer_key_a": var.authorized_signer_key_a,
       "authorized_signer_key_b": var.authorized_signer_key_b })}
EOK
if [ '${var.insecure_private_baking_key == "" ? 1 : 0}' -eq "1" ]; then
cat <<EOLBP > loadbalancerpatch.yaml
${templatefile("${path.module}/../k8s/loadbalancerpatch.yaml.tmpl",
   { "signer_forwarder_target_address" : google_compute_address.signer_forwarder_target[0].address })}
EOLBP
fi
kubectl apply -k .
popd
rm -rvf ${path.module}/k8s-${var.kubernetes_namespace}
EOF

  }
  depends_on = [ null_resource.push_containers, kubernetes_namespace.tezos_namespace ]
}
