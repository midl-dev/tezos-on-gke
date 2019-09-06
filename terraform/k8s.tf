# Query the client configuration for our current service account, which shoudl
# have permission to talk to the GKE cluster since it created it.
data "google_client_config" "current" {
}

# This file contains all the interactions with Kubernetes
provider "kubernetes" {
  load_config_file = false
  host             = google_container_cluster.tezos_baker.endpoint

  cluster_ca_certificate = base64decode(
    google_container_cluster.tezos_baker.master_auth[0].cluster_ca_certificate,
  )
  token = data.google_client_config.current.access_token
}

# Write the secret
resource "kubernetes_secret" "hot_wallet_private_key" {
  metadata {
    name = "hot-wallet"
  }

  data = {
    "hot_wallet_private_key" = "${var.hot_wallet_private_key}"
  }
}

resource "null_resource" "push_containers" {

  triggers = {
    host = md5(google_container_cluster.tezos_baker.endpoint)
    client_certificate = md5(
      google_container_cluster.tezos_baker.master_auth[0].client_certificate,
    )
    client_key = md5(google_container_cluster.tezos_baker.master_auth[0].client_key)
    cluster_ca_certificate = md5(
      google_container_cluster.tezos_baker.master_auth[0].cluster_ca_certificate,
    )
  }
  provisioner "local-exec" {
    command = <<EOF
gcloud auth configure-docker --project "${google_container_cluster.tezos_baker.project}"

find ${path.module}/../docker -mindepth 1 -type d  -printf '%f\n'| while read container; do
  pushd ${path.module}/../docker/$container
  sed -e "s/((tezos_network))/${var.tezos_network}/" Dockerfile.template > Dockerfile
  tag="gcr.io/${google_container_cluster.tezos_baker.project}/$container:latest"
  docker build -t $tag .
  docker push $tag
  rm -v Dockerfile
  popd
done
EOF
  }
}

resource "null_resource" "apply" {
  triggers = {
    host = md5(google_container_cluster.tezos_baker.endpoint)
    client_certificate = md5(
      google_container_cluster.tezos_baker.master_auth[0].client_certificate,
    )
    client_key = md5(google_container_cluster.tezos_baker.master_auth[0].client_key)
    cluster_ca_certificate = md5(
      google_container_cluster.tezos_baker.master_auth[0].cluster_ca_certificate,
    )
  }
  provisioner "local-exec" {
    command = <<EOF
gcloud container clusters get-credentials "${google_container_cluster.tezos_baker.name}" --region="${google_container_cluster.tezos_baker.region}" --project="${google_container_cluster.tezos_baker.project}"

cd ${path.module}/../tezos-baker
cat << EOK > kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- tezos-public-node-stateful-set.yaml
- tezos-private-node-deployment.yaml
- tezos-remote-signer-forwarder.yaml
- backerei-payout.yaml

imageTags:
  - name: tezos/tezos
    newTag: ${var.tezos_network}
  - name: tezos-baker-with-remote-signer
    newName: gcr.io/${google_container_cluster.tezos_baker.project}/tezos-baker-with-remote-signer
    newTag: latest
  - name: tezos-endorser-with-remote-signer
    newName: gcr.io/${google_container_cluster.tezos_baker.project}/tezos-endorser-with-remote-signer
    newTag: latest
  - name: tezos-remote-signer-forwarder
    newName: gcr.io/${google_container_cluster.tezos_baker.project}/tezos-remote-signer-forwarder
    newTag: latest
  - name: tezos-snapshot-downloader
    newName: gcr.io/${google_container_cluster.tezos_baker.project}/tezos-snapshot-downloader
    newTag: latest
  - name: tezos-archive-downloader
    newName: gcr.io/${google_container_cluster.tezos_baker.project}/tezos-archive-downloader
    newTag: latest
  - name: tezos-private-node-connectivity-checker
    newName: gcr.io/${google_container_cluster.tezos_baker.project}/tezos-private-node-connectivity-checker
    newTag: latest

configMapGenerator:
- name: tezos-configmap
  literals:
  - SNAPSHOT_URL="${var.snapshot_url}"
  - ARCHIVE_URL="${var.archive_url}"
  - PUBLIC_BAKING_KEY="${var.public_baking_key}"
  - NODE_HOST="localhost"
  - PROTOCOL="004-Pt24m4xi"
  - PROTOCOL_SHORT="Pt24m4xi"
  - DATA_DIR=/var/run/tezos
- name: remote-signer-forwarder-configmap
  literals:
  - AUTHORIZED_SIGNER_KEY_A="${var.authorized_signer_key_a}"
  - AUTHORIZED_SIGNER_KEY_B="${var.authorized_signer_key_b}"
- name: backerei-payout-configmap
  literals:
  - HOT_WALLET_PUBLIC_KEY="${var.hot_wallet_public_key}" 

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
  depends_on = [null_resource.push_containers, kubernetes_secret.hot_wallet_private_key]
}
