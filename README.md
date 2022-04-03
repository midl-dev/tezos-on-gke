Tezos-on-GKE
============

[Tezos](http://tezos.gitlab.io/mainnet/) is a [delegated proof of stake](https://bitshares.org/technology/delegated-proof-of-stake-consensus/) blockchain protocol.

This deploys:

* a fully featured, [best practices](https://medium.com/tezos/its-a-baker-s-life-for-me-c214971201e1) Tezos baking service on Google Kubernetes Engine, or
* a set of public nodes with a public RPC endpoint ([see documentation](https://tezos-docs.midl.dev/deploy-public-node.html)).

The private baking key can be managed two ways:

* a hot private key stored as a Kubernetes secret for testing purposes
* support for a ssh-tunneled remote signing setup, for production mainnet bakers

Features:

* high availaibility baking, endorsing and accusing
* ssh endpoint for remote signing
* compatible with Tezos mainnet and testnets such as Florencenet
* blockchain snapshot download and import for faster synchronization of the nodes
* support for two highly available signers
* deploy everything in just one command
* metric-based monitoring and alerting with prometheus

Brought to you by MIDL.dev
--------------------------

<img src="midl-dev-logo.png" alt="MIDL.dev" height="100"/>

We maintain [Tezos Suite](https://tezos-docs.midl.dev/), a complete baking suite, free for anyone to use.

We help you deploy and manage a complete Tezos baking operation. [Hire us](https://midl.dev/tezos).

Architecture
------------

This is a Kubernetes private cluster with Tezos nodes located in two Google Cloud zones, in the same region.

The setup is production hardened:
* usage of kubernetes secrets to store sensitive values such as node keys. They are created securely from terraform variables,
* network policies to restrict communication between pods. For example, only sentries can peer with the validator node.

[See full documentation](https://tezos-docs.midl.dev/)

Cost
----

Deploying will incur Google Compute Engine charges, specifically:

* virtual machines
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

NOTE: for production deployments, the method above is not recommended. Instead, you should use a Terraform service account following [these instructions](https://tezos-docs.midl.dev/production-readiness.html).


## Populate terraform variables

All custom values unique to your deployment are set as terraform variables. You must populate these variables manually before deploying the setup.

A simple way is to populate a file called `terraform.tfvars`.

NOTE: `terraform.tfvars` is not recommended for a production deployment. See [production hardening](https://tezos-docs.midl.dev/production-readiness.html).

(1) Clone the repository https://github.com/midl-dev/tezos-on-gke

(2) Go to `terraform` folder in the cloned repository:

```
cd terraform
```

Below is a list of variables you can set.

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| baking\_nodes | Structured data related to baking, including public key and signer configuration. | `map` | `{}` | no |
| billing\_account | Google Cloud billing account ID. | `string` | `""` | no |
| cluster\_ca\_certificate | Kubernetes cluster certificate. | `string` | `""` | no |
| cluster\_name | Name of the Kubernetes cluster. | `string` | `""` | no |
| experimental\_active\_standby\_mode | Enable exeprimental active-standby mode (https://tezos-docs.midl.dev/active-standby.html). | `bool` | `false` | no |
| history\_mode | History mode of the Tezos nodes (rolling, full or archive). | `string` | `"rolling"` | no |
| kubernetes\_access\_token | Access token for the kubernetes endpoint | `string` | `""` | no |
| kubernetes\_endpoint | Name of the Kubernetes endpoint. | `string` | `""` | no |
| kubernetes\_name\_prefix | Kubernetes name prefix to prepend to all resources (should be short, like xtz). | `string` | `"xtz"` | no |
| kubernetes\_namespace | Kubernetes namespace to deploy the resource into. | `string` | `"tezos"` | no |
| kubernetes\_pool\_name | When Kubernetes cluster has several node pools, specify which ones to deploy the baking setup into. Only effective when deploying on an external cluster with terraform\_no\_cluster\_create | `string` | `"blockchain-pool"` | no |
| monitoring\_slack\_url | Slack API URL to send prometheus alerts to. | `string` | `""` | no |
| node\_locations | Zones in which to create the nodes. | `list` | <pre>[<br>  "us-central1-b",<br>  "us-central1-f"<br>]</pre> | no |
| node\_storage\_size | Storage size for the nodes, in gibibytes (GiB). | `string` | `"15"` | no |
| org\_id | Google Cloud organization ID. | `string` | `""` | no |
| project | Project ID where Terraform is authenticated to run to create additional projects. If provided, Terraform will great the GKE and Tezos cluster inside this project. If not given, Terraform will generate a new project. | `string` | `""` | no |
| protocols | The list of Tezos protocols currently in use, following the naming convention used in the baker binary names, for example 007-PsDELPH1. Baking and endorsing daemons will be spun up for every protocol provided in the list, which helps for seamless protocol updates. | `list` | <pre>[<br>  "007-PsDELPH1",<br>  "008-PtEdoTez"<br>]</pre> | no |
| region | Region in which to create the cluster, or region where the cluster exists. | `string` | `"us-central1"` | no |
| rpc\_public\_hostname | If set, expose the RPC of the public node through a load balancer and create a certificate for the given hostname. | `string` | `""` | no |
| rpc\_subnet\_whitelist | IP address whitelisting for the public RPC. Open to everyone by default. | `list` | <pre>[<br>  "0.0.0.0/0"<br>]</pre> | no |
| signer\_target\_host\_key | SSH host key for the SSH endpoint the remote signer connects to. If left empty, sshd will generate it but it may change, cutting your access to the remote signers. | `string` | `""` | no |
| snapshot\_url | URL of the snapshot of type rolling to download. | `string` | `"https://mainnet.xtz-shots.io/rolling"` | no |
| terraform\_service\_account\_credentials | Path to terraform service account file, created following the instructions in https://cloud.google.com/community/tutorials/managing-gcp-projects-with-terraform | `string` | `"~/.config/gcloud/application_default_credentials.json"` | no |
| tezos\_network | The Tezos network such as mainnet, edonet, etc. | `string` | `"mainnet"` | no |
| tezos\_version | The Tezos container version for node. Should be hard-coded to a version from https://hub.docker.com/r/tezos/tezos/tags. Not recommended to set to a rolling tag like 'mainnet', because it may break unexpectedly. Example: `v9.2`. | `string` | `"latest-release"` | no |


### Baking nodes

The `baking_nodes` parameter lets you deploy one or several bakers declaratively by passing structured data describing the bakers.

You may specify:
* a map with one or several baking nodes, and
* for every baking node, one or several baking and endorsing processes.

The variables needed to spin up the baking or endorsing processes are:

* `public_baking_key`: the public baking key starting with `edpk`
* `public_baking_key_hash`: the public baking key hash starting with `tz`
* for testnets or test deployments only: set the `insecure_private_baking_key` to the unencrypted private key to be used.

**Attention!** Leaving a private baking key on a cloud platform is not recommended when funds are present. For production bakers, leave this variable empty and use a remote signer. [See documentation](https://tezos-docs.midl.dev/).

To generate a public/private keypair, you can use the tezos client:

```
tezos-client gen keys insecure-baker
# if you do not have a node running locally, there will be an error, but the key was created anyway
tezos-client show address insecure-baker -S
```

Set `public_baking_key_hash` to the value displayed after `Hash:`, `public_baking_key` to the value displayed after `Public key:`  and `insecure_private_baking_key` to the value displayed after `Secret key: unencrypted:`.

If you do not have the tezos client installed locally, you can use the docker Tezos container:

```
docker run --name=my-tezos-client tezos/tezos:latest-release tezos-client gen keys insecure-baker
# again, if you do not have a node running locally, there will be an error, but the key was created anyway
docker commit my-tezos-client my-tezos-client
docker run my-tezos-client tezos-client show address insecure-baker -S
```

Full example of `baking_nodes` parameter:

```
mybaker = {
  public_baking_key="edpkup8PaxJYrUcXUEBEufekgqMaodyKLKwHqbtkQVAudiJ7nmrS2o"
  public_baking_key_hash="tz1YmsrYxQFJo5nGj4MEaXMPdLrcRf2a5mAU"
  insecure_private_baking_key="edsk3cftTNcJnxb7ehCxYeCaKPT7mjycdMxgFisLixrQ9bZuTG2yZK"
}
```

If you do not want to bake (for example, if you want to deploy a RPC node only), configure just one node with no baker:

```
baking_nodes = { "mynode": {} }
```

### Payouts

Tezos-on-GKE supports the [Tezos Rewards Distributor (TRD)](https://github.com/tezos-reward-distributor-organization/tezos-reward-distributor) running as a cronjob alongside the baker node, sharing the same remote signing infrastructure.

All details are in the [tezos-suite documentation](https://tezos-docs.midl.dev/trd-payouts.html).

### Full example

Here is a full example `terraform.tfvars` configuration. This private key is provided only as an example, generate your own instead.

```
project="<your Google project name>"
tezos_network="florencenet"
snapshot_url="https://florencenet.xtz-shots.io/rolling"
baking_nodes = {
  mynode = {
    mybaker = {
      public_baking_key="edpkup8PaxJYrUcXUEBEufekgqMaodyKLKwHqbtkQVAudiJ7nmrS2o"
      public_baking_key_hash="tz1YmsrYxQFJo5nGj4MEaXMPdLrcRf2a5mAU"
      insecure_private_baking_key="edsk3cftTNcJnxb7ehCxYeCaKPT7mjycdMxgFisLixrQ9bZuTG2yZK"
    }
  }
}
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
* build the necessary containers
* spin up the baker nodes

In case of error, run the `plan` and `apply` steps again:

```
terraform plan -out plan.out
terraform apply plan.out
```

### Connect to the cluster

Once the command returns, you can verify that the pods are up by running:

```
kubectl get pods
```

You should see the tezos node.

Display the log of a public node and observe it sync:

```
kubectl logs -f tezos-public-node-0 --tail=10
```

## Use with a remote signer

It is not recommended to run a production baker with cloud-hosted private keys.

Follow [our guide](https://tezos-docs.midl.dev/deploy-remote-signer.html) to configure a hardware remote signer connected to a Ledger.

When using this mode, you must pass a `baking_nodes` map with the following parameters:

* `ledger_authorized_path`: the Ledger path associated with the key stored in Ledger device on the remote signer,
* `public_baking_key`: the public key for the key stored in the Ledger device
* `public_baking_key_hash`: the public key hash for the key stored in the Ledger device
* `monitoring_slack_url` and `monitoring_slack_channel`: optional, the Slack channel where to send the signer-specific alerts
* `authorized_signers`: a list of signer specification maps, containing:
  * `ssh_pubkey`: the public key of the signer, used for ssh port forwarding, and
  * `signer_port`: the port for the signer http endpoint that is being tunneled
  * `tunnel_endpoint_port`: the port where the ssh daemon connects to on the load balancer for tunneling traffic

## Day 2 operations

[See documentation](https://tezos-docs.midl.dev/day-2-operations)

## Wrapping up

To delete everything and terminate all the charges, issue the command:

```
terraform destroy
```

Alternatively, go to the GCP console and delete the project.
