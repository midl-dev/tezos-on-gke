Tezos-on-GKE
============

[Tezos](http://tezos.gitlab.io/mainnet/) is a [delegated proof of stake](https://bitshares.org/technology/delegated-proof-of-stake-consensus/) blockchain protocol.

This deploys a fully featured, [best practices](https://medium.com/tezos/its-a-baker-s-life-for-me-c214971201e1) Tezos baking service on Google Kubernetes Engine.

The private baking key can be managed two ways:

* a hot private key stored as a Kubernetes secret for testing purposes
* support for a ssh-tunneled remote signing setup, for production mainnet bakers

Features:

* high availaibility baking, endorsing and accusing
* baking node is protected behind two sentry nodes
* ssh endpoint for remote signing
* compatible with Tezos mainnet and testnets such as Carthagenet
* blockchain snapshot download and import for faster synchronization of the nodes
* support for two highly available signers
* deploy everything in just one command
* TODO:
  * metric-based monitoring and alerting with prometheus

Brought to you by MIDL.dev
--------------------------

<img src="midl-dev-logo.png" alt="MIDL.dev" height="100"/>

We maintain a reference architecture for Tezos baking, free for anyone to use.

We help you deploy and manage a complete Tezos baking operation. [Hire us](https://midl.dev).

Architecture
------------

This is a Kubernetes private cluster with two nodes located in two Google Cloud zones, in the same region.

The sentry (public) nodes are a StatefulSet of two pods, one in each zone. They connect to the peer-to-peer network.

A private node performs bakings and endorsements. It connects exclusively to the two public nodes belonging to the cluster.

The baker node uses a [Regional Persistent Disk](https://cloud.google.com/compute/docs/disks/#repds) so it can be respun quickly in the other node from the pool if the first node goes offline for any reason, for example base OS upgrade.

The setup is production hardened:
* usage of kubernetes secrets to store sensitive values such as node keys. They are created securely from terraform variables,
* network policies to restrict communication between pods. For example, only sentries can peer with the validator node.

Cost
----

Deploying will incur Google Compute Engine charges, specifically:

* virtual machines
* regional persistent SSD storage
* network ingress
* NAT forwarding

# How to deploy

*WARNING: Use judgement and care in your network interactions, otherwise loss of funds may occur.*

## Prerequisites

1. Download and install [Terraform](https://terraform.io)

1. Download, install, and configure the [Google Cloud SDK](https://cloud.google.com/sdk/).

1. Install the [kubernetes
   CLI](https://kubernetes.io/docs/tasks/tools/install-kubectl/) (aka
   `kubectl`)


## Authentication

Using your Google account, active your Google Cloud access.

Login to gcloud using `gcloud auth login`

Set up [Google Default Application Credentials](https://cloud.google.com/docs/authentication/production) by issuing the command:

```
gcloud auth application-default login
```

NOTE: for production deployments, the method above is not recommended. Instead, you should use a Terraform service account following [these instructions](docs/production-hardening.md).


## Populate terraform variables

All custom values unique to your deployment are set as terraform variables. You must populate these variables manually before deploying the setup.

A simple way is to populate a file called `terraform.tfvars`.

NOTE: `terraform.tfvars` is not recommended for a production deployment. See [production hardening](docs/production-hardening.md).

First, go to `terraform` folder:

```
cd terraform
```

Below is a list of variables you must set.

### Google Cloud project

A default Google Cloud project should have been created when you activated your account. Verify its ID with `gcloud projects list`. You may also create a dedicated project to deploy the cluster.

Set the project id in the `project` terraform variable.

NOTE: if you created a [terraform service account](docs/production-hardening.md), leave this variable empty.

### Tezos network

Set the `tezos_network` variable to the network to use (`mainnet`, `carthagenet`, etc)

### Baking address

Set the `public_baking_key` variable to the baking address.

For testnets or test deployments only: set the `insecure_private_baking_key` to the unencrypted private key to be used.

**Attention!** Leaving a private baking key on a cloud platform is not recommended when funds are present. For production bakers, leave this variable empty. Leaving it empty will prompt terraform to create a ssh endpoint for remote signers to connect to.

To generate a public/private keypair, you can use the tezos client:

```
tezos-client gen keys insecure-baker
# if you do not have a node running locally, there will be an error, but the key was created anyway
tezos-client show address insecure-baker -S
```

Set `public_baking_key` to the value displayed after `Hash:` and `insecure_private_baking_key` to the value displayed after `Secret key: unencrypted:`.

If you do not have the tezos client installed locally, you can use the docker Tezos container:

```
docker run --name=my-tezos-client tezos/tezos:latest-release tezos-client gen keys insecure-baker
# again, if you do not have a node running locally, there will be an error, but the key was created anyway
docker commit my-tezos-client my-tezos-client
docker run my-tezos-client tezos-client show address insecure-baker -S
```


### Full example

Here is a full example `terraform.tfvars` configuration. Obviously do not use this one as the private key is now widely known:

```
project="beaming-essence-20718"
tezos_network="carthagenet"
public_baking_key="tz1YmsrYxQFJo5nGj4MEaXMPdLrcRf2a5mAU"
insecure_private_baking_key="edsk3cftTNcJnxb7ehCxYeCaKPT7mjycdMxgFisLixrQ9bZuTG2yZK"
```

## Deploy!

1. Run the following:

```
terraform init
terraform plan -out plan.out
terraform apply plan.out
```

This will take time as it will:
* create a Google Cloud project
* create a Kubernetes cluster
* build the necessary containers locally
* spin up the public nodes and private baker nodes

### Connect to the cluster

Once the command returns, you can verify that the pods are up by running:

```
kubectl get pods
```

You should see 2 public nodes and one private node.

Display the log of a public node and observe it sync:

```
kubectl logs -f tezos-public-node-0 --tail=10
```

## Day 2 operations

### Apply an update

If you have pulled the most recent version of `tezos-on-gke` and wish to apply updates, you may do so with a `terraform taint`:

```
terraform taint null_resource.push_containers && terraform taint null_resource.apply && terraform plan -out plan.out
terraform apply plan.out
```

This will rebuild the containers locally, then do a `kubectl apply` to push the most recent changes to your cluster.

The daemons will restart after some time. However, you may kill the pods to restart them immediately.

### Tezos Protocol update

When the Tezos protocol changes, be sure to edit the terraform variables `protocol` and `protocol_short` to match the new version.

Then, apply the changes. Your baker will restart with the right baking and endorsing daemons.

### Remotely ssh into the remote signers

For remote connectivity and debugging purposes, ssh port 22 for the on-prem remote signers is being forwarded on ports 9443 and 9444.

To connect to the signers, forward port 9443/9444 from the `tezos-remote-signer-forwarder` locally, then ssh to localhost using your private key associated with the public key injected into the baker during initial setup.

## Wrapping up

To delete everything and terminate all the charges, issue the command:

```
terraform destroy
```

Alternatively, go to the GCP console and delete the project.
