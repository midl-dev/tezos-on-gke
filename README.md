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
 * one command deployment with Cloud Deployment Manager
 * automatic payouts from a hot wallet with Backerei
 * support for two highly available signers
 * liveliness check of signers with canary signatures

Architecture
------------

This is a Kubernetes private cluster with two nodes located in two Google Cloud zones.

A StatefulSet of two public nodes is connected to the Tezos peer to peer network. As the cluster sits behind a NAT, the nodes initiate connections to public nodes, but are not discoverable.

A private Tezos baking node performs signing, endorsing and accusing. It synchronizes exclusively with the two public nodes belonging to the cluster.

An ssh endpoint is accessed by the remote signer (outside of this setup) to establish a tunnel to the signing daemon.

The remote signer is connected to a Ledger Nano S running the Tezos Baking app.

High availability
-----------------

Google guarantees 99.99% SLA on a highly available cluster provided that the Kubernetes deployment itself is highly available. We are using different means to this end.

The StatefulSet ensures that each public Tezos node is running in a different cluster node, so a zone failure does not affect functionality.

The private Tezos Node must not run in two locations at once, lest you are at risk of double baking and getting your funds slashed. Instead of a StatefulSet, a highly available pod backed by a [Regional Persistent Disk](https://cloud.google.com/compute/docs/disks/#repds) is used. In case of a Google Zone maintenance or failure, the baking pod is restarted in the other zone in an already synchronized state.

It is recommended that the signer has a redundant power supply as well as battery backup. It should also have redundant access to the internet. It should be kept in a location with physical access control as any disconnection event on the Ledger wallet will require entering the PIN.

How to deploy
-------------

Create a Google Cloud project.

Create a VPC virtual private network named `tezos-gke-network` with a subnet `tezos-gke-subnet`. Open the ssh port in the firewall, create a bastion host, and enable cloud NAT for external connectivity of the nodes. [This Google Cloud tutorial](https://cloud.google.com/nat/docs/gke-example) explains all these steps.

Start a highly available GKE cluster:

```
 gcloud beta container clusters create tezos-on-gke  --machine-type=n1-standard-2   --region=us-central1  --num-nodes=1  --node-locations=us-central1-b,us-central1-f  --enable-cloud-logging --enable-cloud-monitoring --enable-ip-alias --network "projects/<MY PROJECT>/global/networks/tezos-gke-network" --subnetwork "projects/<MY PROJECT>/regions/us-central1/subnetworks/tezos-gke-subnet" --default-max-pods-per-node "110" --addons HorizontalPodAutoscaling,HttpLoadBalancing --enable-autoupgrade --enable-autorepair --enable-vertical-pod-autoscaling  --image-type "COS" --disk-type "pd-standard" --disk-size "25"
```

Build and push the containers located in the `docker` onto the private registry.

Then deploy the Kubernetes resources located in `k8s-resources` folder:

```
kubectl apply -f tezos-private-node-deployment.yaml
kubectl apply -f tezos-public-node-stateful-set.yaml
```

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
