[WIP] Tezos-on-GKE
==================

[Tezos](http://tezos.gitlab.io/mainnet/) is a [delegated proof of stake](https://bitshares.org/technology/delegated-proof-of-stake-consensus/) blockchain protocol.

This deploys a fully featured, [best practices](https://medium.com/tezos/its-a-baker-s-life-for-me-c214971201e1) Tezos baking service on Google Kubernetes Engine.

This setup does not include the signer for the baking keys. These keys should be exposed by a remote signer connected to a Hardware Security Module under your control.

Features:

* high availaibility baking, endorsing and accusing
* ssh endpoint for remote signing
* compatible with mainnet and alphanet
* blockchain snapshot download and import from a public URL for faster synchronization of the nodes
* TODO:
  * one-command deployment with Cloud Deployment Manager
  * automatic payouts from a hot wallet with Backerei
  * support for two highly available signers
  * liveliness check of signers with canary signatures

Architecture
------------

This is a Kubernetes private cluster with two nodes located in two Google Cloud zones.

A StatefulSet of two public nodes is connected to the Tezos peer to peer network. As the cluster sits behind a NAT, the nodes initiate connections to public nodes, but are not discoverable.

A private Tezos baking node performs signing, endorsing and accusing. It synchronizes exclusively with the two public nodes belonging to the cluster.

An ssh endpoint is accessed by the remote signer (outside of GKE) to establish a tunnel to the signing daemon.

The remote signer is connected to a Ledger Nano S running the [Tezos Baking app](https://github.com/obsidiansystems/ledger-app-tezos).

<img src="./k8s-baker.svg">

High availability
-----------------

Google guarantees 99.99% SLA on a highly available cluster provided that the Kubernetes deployment itself is highly available. We are using different means to this end.

The StatefulSet ensures that each public Tezos node is running in a different cluster node, so a zone failure does not affect functionality.

The private Tezos Node must not run in two locations at once, lest you are at risk of double baking and getting your funds slashed. Instead of a StatefulSet, a highly available pod backed by a [Regional Persistent Disk](https://cloud.google.com/compute/docs/disks/#repds) is used. In case of a Google Zone maintenance or failure, the baking pod is restarted in the other zone in an already synchronized state.

It is recommended that the signer have a redundant power supply as well as battery backup. It should also have redundant access to the internet. It should be kept in a location with physical access control as any disconnection event on the Ledger wallet will require entering the PIN.

Dependencies
------------

1. Download and install [Terraform][terraform].

1. Download, install, and configure the [Google Cloud SDK][sdk]. You will need
   to configure your default application credentials so Terraform can run. It
   will run against your default project, but all resources are created in the
   (new) project that it creates.

1. Install the [kubernetes
   CLI](https://kubernetes.io/docs/tasks/tools/install-kubectl/) (aka
   `kubectl`)

1. install and configure docker

How to deploy
-------------

You need a Google Cloud Organization. You will be able to create one as an individual by registering a domain name, or you may use your company's organization.

You need to use a gcloud account as a user that has permission to create new projects. See [instructions for Terraform service account creation](https://cloud.google.com/community/tutorials/managing-gcp-projects-with-terraform) from Google.

1. Collect your organization id and billing account id

1. Run the following:

```
cd terraform
terraform init
terraform plan -var billing_account=<your billing account id> -var org_id=<your org id>  -out out.plan
```

1. it will fail at the helm step (for now)

1. get kubectl credentials

```
gcloud container clusters get-credentials  tezos-baker --region us-central1 --project <enter project name here>
```

1. Give permissions to helm to provision the baker (from https://stackoverflow.com/a/45306258/207209)

```
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
```

1. Push tiller

```
helm init
```

1. Install the helm packages

```
helm install tezos-baker
```

How to deploy (old)
-------------

Create a Google Cloud project.

Create a VPC virtual private network named `tezos-gke-network` with a subnet `tezos-gke-subnet`. Open the ssh port in the firewall, create a bastion host, and enable cloud NAT for external connectivity of the nodes. [This Google Cloud tutorial](https://cloud.google.com/nat/docs/gke-example) explains all these steps.

Start a highly available GKE cluster:

```
 gcloud beta container clusters create tezos-on-gke  --machine-type=n1-standard-2   --region=us-central1  --num-nodes=1  --node-locations=us-central1-b,us-central1-f  --enable-cloud-logging --enable-cloud-monitoring --enable-ip-alias --network "projects/<MY PROJECT>/global/networks/tezos-gke-network" --subnetwork "projects/<MY PROJECT>/regions/us-central1/subnetworks/tezos-gke-subnet" --default-max-pods-per-node "110" --addons HorizontalPodAutoscaling,HttpLoadBalancing --enable-autoupgrade --enable-autorepair --enable-vertical-pod-autoscaling  --image-type "COS" --disk-type "pd-standard" --disk-size "25"
```

Build and push the containers located in the `docker` onto the private registry.

Then deploy the Kubernetes resources located in `k8s-resources` folder. Replace the strings within brackets with relevant values:

```
kubectl apply -f tezos-private-node-deployment.yaml
kubectl apply -f tezos-public-node-stateful-set.yaml
```

Note that alphanet is configured by default. To bake on the mainnet, edit the `image:` values to set the container tag to `mainnet`.

Get the public IPs of the Kubernetes nodes as well as the nodePorts of the exposed services:

```
kubectl get nodes --output wide
kubectl get service tezos-remote-signer-forwarder --output yaml
```

Open the port in the VPC:

```
gcloud compute firewall-rules create myservice --network "projects/<MY PROJECT>/global/networks/tezos-gke-network" --allow tcp:<NODE PORT>
```

The remote signer may now connect to the ip/port combination. The `remote-signer` folder contains systemd scripts to ensure that this will reliably work and retry on failure.

Copy these files to `/etc/systemd/system/` on the remote signer, set the IP/port correctly inside the scripts then issue:

```
systemctl enable tezos-signer
systemctl enable tezos-signer-forwarder
systemctl start tezos-signer
systemctl start tezos-signer-forwarder
```

Security considerations
-----------------------

The main security risk of this setup is operator error. It is recommended to stage any new deployment of this code to an alphanet cluster before rolling it out against actual funds.

Another risk is related to the avaialability of the signer.

The baking keys can not be kept in a cold storage address, since a message must be signed for each endorsment. But they must be protected by some sort of hardware bastion, so if an attacker gains access to any part of the setup, they may not walk away with the keys. In this simple setup, we used a Ledger Nano. Larger operations may use a cloud HSM.

The Ledger Nano baking app is deliberately separate from the regular Tezos app, so it can not be used to send payouts to delegators. The payouts should be sent from another address, which is kept in a hot wallet. It is discouraged to automate replenishing the payout address from the baking address, as this would require the baking address to be kept in a hot wallet.

There are also risks inherent with using GCP, such as loosing access to your credentials, getting hacked, or getting your account terminated by your provider.
