# Pre-existing kubernetes cluster

You may want to deploy the baker setup in a kubernetes cluster that already exists.

In that case:

* set the `kubernetes_config_context` variable to the context of your target cluster. To list local contexts, do `kubectl config get-contexts` or look at `~/.kube/config`
* set the `project` variable to the GCP project where the cluster is located
* `terraform init` / `terraform plan` / `terraform apply`

When the `kubernetes_confic_context` variable is set, terraform will skip cluster creation and directly deploy kubernetes resources.
