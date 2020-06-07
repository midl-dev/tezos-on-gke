resource "null_resource" "push_containers" {

  triggers = {
    host = md5(module.terraform-gke-blockchain.kubernetes_endpoint)
    cluster_ca_certificate = md5(
      module.terraform-gke-blockchain.cluster_ca_certificate,
    )
  }
  provisioner "local-exec" {
    command = <<EOF


find ${path.module}/../docker -mindepth 1 -type d  -printf '%f\n'| while read container; do
  
  pushd ${path.module}/../docker/$container
  cp Dockerfile.template Dockerfile
  sed -i "s/((tezos_sentry_version))/${var.tezos_sentry_version}/" Dockerfile
  sed -i "s/((tezos_private_version))/${var.tezos_private_version}/" Dockerfile
  cat << EOY > cloudbuild.yaml
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', "gcr.io/${module.terraform-gke-blockchain.project}/$container:latest", '.']
images: ["gcr.io/${module.terraform-gke-blockchain.project}/$container:latest"]
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

resource "local_file" "k8s_kustomization" {
  content = templatefile("${path.module}/../k8s/kustomization.yaml.tmpl",
     { "project" : module.terraform-gke-blockchain.project,
       "public_baking_key": var.public_baking_key,
       "insecure_private_baking_key": var.insecure_private_baking_key,
       "tezos_private_version": var.tezos_private_version,
       "protocol": var.protocol,
       "protocol_short": var.protocol_short,
       "authorized_signer_key_a": var.authorized_signer_key_a,
       "authorized_signer_key_b": var.authorized_signer_key_b })
  filename = "${path.module}/../k8s/kustomization.yaml"
}

resource "local_file" "k8s_load_balancer_patch" {
  count = var.insecure_private_baking_key == "" ? 1 : 0
  content = templatefile("${path.module}/../k8s/loadbalancerpatch.yaml.tmpl",
     { "signer_forwarder_target_address" : google_compute_address.signer_forwarder_target[0].address })
  filename = "${path.module}/../k8s/loadbalancerpatch.yaml"
}

resource "null_resource" "apply" {
  provisioner "local-exec" {
    command = <<EOF
set -e
set -x
if [ "${module.terraform-gke-blockchain.name}" != "" ]; then
  gcloud container clusters get-credentials "${module.terraform-gke-blockchain.name}" --region="${module.terraform-gke-blockchain.location}" --project="${module.terraform-gke-blockchain.project}"
else
  kubectl config use-context "${var.kubernetes_config_context}"
fi

cd ${path.module}/../k8s
kubectl apply -k .
EOF

  }
  depends_on = [ null_resource.push_containers ]
}
