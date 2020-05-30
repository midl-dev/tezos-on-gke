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
  name    = "tezos-baker-lb"
  region  = module.terraform-gke-blockchain.location
  project = module.terraform-gke-blockchain.project
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
cat << EOK > kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- tezos-public-node-stateful-set.yaml
- tezos-private-node-deployment.yaml
- tezos-remote-signer-forwarder.yaml

imageTags:
  - name: tezos-public-node-with-probes
    newName: gcr.io/${module.terraform-gke-blockchain.project}/tezos-public-node-with-probes
    newTag: latest
  - name: tezos/tezos
    newTag: ${var.tezos_private_version}
  - name: tezos-baker-with-remote-signer
    newName: gcr.io/${module.terraform-gke-blockchain.project}/tezos-baker-with-remote-signer
    newTag: latest
  - name: tezos-endorser-with-remote-signer
    newName: gcr.io/${module.terraform-gke-blockchain.project}/tezos-endorser-with-remote-signer
    newTag: latest
  - name: tezos-remote-signer-forwarder
    newName: gcr.io/${module.terraform-gke-blockchain.project}/tezos-remote-signer-forwarder
    newTag: knownworking
  - name: tezos-remote-signer-loadbalancer
    newName: gcr.io/${module.terraform-gke-blockchain.project}/tezos-remote-signer-loadbalancer
    newTag: latest
  - name: tezos-snapshot-downloader
    newName: gcr.io/${module.terraform-gke-blockchain.project}/tezos-snapshot-downloader
    newTag: latest
  - name: tezos-archive-downloader
    newName: gcr.io/${module.terraform-gke-blockchain.project}/tezos-archive-downloader
    newTag: latest
  - name: tezos-key-importer
    newName: gcr.io/${module.terraform-gke-blockchain.project}/tezos-key-importer
    newTag: latest
  - name: tezos-private-node-connectivity-checker
    newName: gcr.io/${module.terraform-gke-blockchain.project}/tezos-private-node-connectivity-checker
    newTag: latest
  - name: website-builder
    newName: gcr.io/${module.terraform-gke-blockchain.project}/website-builder

configMapGenerator:
- name: tezos-configmap
  literals:
  - PUBLIC_BAKING_KEY="${var.public_baking_key}"
  - NODE_HOST="localhost"
  - PROTOCOL="${var.protocol}"
  - PROTOCOL_SHORT="${var.protocol_short}"
  - DATA_DIR=/var/run/tezos
- name: remote-signer-forwarder-configmap
  literals:
  - AUTHORIZED_SIGNER_KEY_A="${var.authorized_signer_key_a}"
  - AUTHORIZED_SIGNER_KEY_B="${var.authorized_signer_key_b}"

patchesStrategicMerge:
- loadbalancerpatch.yaml
EOK
cat << EOP > loadbalancerpatch.yaml
apiVersion: v1
kind: Service
metadata:
  name: tezos-remote-signer-forwarding-ingress
spec:
  loadBalancerIP: ${google_compute_address.signer_forwarder_target.address}
EOP
kubectl apply -k .
EOF

  }
  depends_on = [ null_resource.push_containers ]
}
