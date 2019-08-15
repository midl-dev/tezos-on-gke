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
resource "kubernetes_secret" "tezos-baker-tls" {
  metadata {
    name = "tezos-baker-tls"
  }

  data = {
    "tezos_baker.crt" = "cul"
    "tezos_baker.key" = "chatte"
    "ca.crt"    = "bitul"
  }
}

# Submit the job - Terraform doesn't yet support StatefulSets, so we have to
# shell out.
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

  depends_on = [kubernetes_secret.tezos-baker-tls]

  provisioner "local-exec" {
    command = <<EOF
gcloud container clusters get-credentials "${google_container_cluster.tezos_baker.name}" --region="${google_container_cluster.tezos_baker.region}" --project="${google_container_cluster.tezos_baker.project}"

CONTEXT="gke_${google_container_cluster.tezos_baker.project}_${google_container_cluster.tezos_baker.region}_${google_container_cluster.tezos_baker.name}"
echo 'ahem' | kubectl apply -n default --context="$CONTEXT" -f -
EOF

  }
}

# Wait for all the servers to be ready
resource "null_resource" "wait-for-finish" {
  provisioner "local-exec" {
    command = <<EOF
for i in $(seq -s " " 1 15); do
  sleep $i
  if [ $(kubectl get pod -n default | grep tezos_baker | wc -l) -eq 2 ]; then
    exit 0
  fi
done

echo "Pods are not ready after 2m"
exit 1
EOF

}

depends_on = [null_resource.apply]
}
