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

resource "kubernetes_secret" "website_builder_key" {
  metadata {
    name = "website-builder-credentials"
  }
  data = {
    json_key = "${base64decode(google_service_account_key.website_builder_key.private_key)}"
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
  cp Dockerfile.template Dockerfile
  sed -i "s/((tezos_sentry_version))/${var.tezos_sentry_version}/" Dockerfile
  sed -i "s/((tezos_private_version))/${var.tezos_private_version}/" Dockerfile
  tag="gcr.io/${google_container_cluster.tezos_baker.project}/$container:latest"
  podman build --format docker -t $tag .
  podman push $tag
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

imageTags:
  - name: tezos-public-node-with-probes
    newName: gcr.io/${google_container_cluster.tezos_baker.project}/tezos-public-node-with-probes
    newTag: latest
  - name: tezos/tezos
    newTag: ${var.tezos_private_version}
  - name: tezos-baker-with-remote-signer
    newName: gcr.io/${google_container_cluster.tezos_baker.project}/tezos-baker-with-remote-signer
    newTag: latest
  - name: tezos-endorser-with-remote-signer
    newName: gcr.io/${google_container_cluster.tezos_baker.project}/tezos-endorser-with-remote-signer
    newTag: latest
  - name: tezos-remote-signer-forwarder
    newName: gcr.io/${google_container_cluster.tezos_baker.project}/tezos-remote-signer-forwarder
    newTag: latest
  - name: tezos-remote-signer-loadbalancer
    newName: gcr.io/${google_container_cluster.tezos_baker.project}/tezos-remote-signer-loadbalancer
    newTag: latest
  - name: tezos-snapshot-downloader
    newName: gcr.io/${google_container_cluster.tezos_baker.project}/tezos-snapshot-downloader
    newTag: latest
  - name: tezos-archive-downloader
    newName: gcr.io/${google_container_cluster.tezos_baker.project}/tezos-archive-downloader
    newTag: latest
  - name: tezos-key-importer
    newName: gcr.io/${google_container_cluster.tezos_baker.project}/tezos-key-importer
    newTag: latest
  - name: tezos-private-node-connectivity-checker
    newName: gcr.io/${google_container_cluster.tezos_baker.project}/tezos-private-node-connectivity-checker
    newTag: latest
  - name: website-builder
    newName: gcr.io/${google_container_cluster.tezos_baker.project}/website-builder

configMapGenerator:
- name: tezos-configmap
  literals:
  - ROLLING_SNAPSHOT_URL="${var.rolling_snapshot_url}"
  - FULL_SNAPSHOT_URL="${var.full_snapshot_url}"
  - PUBLIC_BAKING_KEY="${var.public_baking_key}"
  - NODE_HOST="localhost"
  - PROTOCOL="${var.protocol}"
  - PROTOCOL_SHORT="${var.protocol_short}"
  - DATA_DIR=/var/run/tezos
- name: remote-signer-forwarder-configmap
  literals:
  - AUTHORIZED_SIGNER_KEY_A="${var.authorized_signer_key_a}"
  - AUTHORIZED_SIGNER_KEY_B="${var.authorized_signer_key_b}"
- name: website-builder-configmap
  literals:
  - WEBSITE_ARCHIVE="${var.website_archive}"
  - WEBSITE_BUCKET_URL="${google_storage_bucket.website.url}"
  - PAYOUT_URL="http://payout-json/payouts.json"
  - GOOGLE_APPLICATION_CREDENTIALS="/var/secrets/google/json_key"

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
