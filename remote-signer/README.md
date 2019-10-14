Remote signer
-------------

This is an ansible manifest to turn a Raspberry Pi with Raspbian OS into a remote signer.

You need a Raspberry Pi with a fresh Raspbian install and remote ssh access. To enable ssh access, add a file named `ssh` to the boot partition.

The default credentials will be `pi`/`raspberry`.

You also need

* a Linux environment with ansible installed
* a ssh public/private keypair in your home direcroty `~/.ssh` folder

In the `remote-signer` directory, edit the `inventory` file to set the ip address of your Pi.

Edit the tezos-remote-signer.yaml with the required parameters.

Run the ansible fully automated install:

```
cd remote-signer
ansible-playbook tezos-remote-signer.yaml --inventory-file inventory
```

As part of the installation, it will remove the default `pi` user, add the `tezos` user, disable ssh password access, enable public-key ssh authenticationas `tezos` user with the public key that is in your `~/.ssh` folder.

The first attempt will fail at that step since ansible is logged in as this user. Error will look like:

```
TASK [tezos-remote-signer : Remove the default raspbian user 'pi'] ***********************************************************************************************************************************************************************************************************************************************************
fatal: [192.168.X.X]: FAILED! => {"changed": false, "msg": "userdel: user pi is currently used by process 992\n", "name": "pi", "rc": 8}
```

At this point, edit your `inventory` file, comment out the following lines:

```
#ansible_ssh_user=pi
#ansible_ssh_pass=raspberry
```

And uncomment:

```
ansible_ssh_user=tezos
```

Then run ansible again:

```
ansible-playbook tezos-remote-signer.yaml --inventory-file inventory
```

At this point, it will perform a firewall configuration change that requires a reboot, then fail with the following:

```
TASK [tezos-remote-signer : Configure ufw defaults] **************************************************************************************************************************************************************************************************************************************************************************
failed: [192.168.X.X] (item={'direction': 'incoming', 'policy': 'deny'}) => {"ansible_loop_var": "item", "changed": false, "commands": ["/usr/sbin/ufw status verbose"], "item": {"direction": "incoming", "policy": "deny"}, "msg": "ERROR: problem running iptables: iptables v1.8.2 (legacy): can't initialize iptables table `filter': Table does not exist (do you need to insmod?)\nPerhaps iptables or your kernel needs to be upgraded.\n\n\n"}
failed: [192.168.X.X] (item={'direction': 'outgoing', 'policy': 'allow'}) => {"ansible_loop_var": "item", "changed": false, "commands": ["/usr/sbin/ufw status verbose"], "item": {"direction": "outgoing", "policy": "allow"}, "msg": "ERROR: problem running iptables: iptables v1.8.2 (legacy): can't initialize iptables table `filter': Table does not exist (do you need to insmod?)\nPerhaps iptables or your kernel needs to be upgraded.\n\n\n"}
```

At this point, login to the device;

```
ssh tezos@192.168.X.X
```

Then reboot:

```
sudo reboot
```

Then run ansible again:

```
ansible-playbook tezos-remote-signer.yaml --inventory-file inventory
```

It will run to completion. As it compiles Tezos on a very low-power CPU, it will take several hours to complete.

Set up the signers
==================

You need both Ledgers connected to your signers to be configured with the same recovery phrase, this way they sign the same account.

*This is your baking key. Keep it safe.*

Open the Ledgers' baking apps then issue the following commands:

```
tezos-signer list connected ledgers
```

It will give you a command with an animal menmonic address to import the key. Enter it in your terminal. Note that you need to import it to both the client and the signer.

```
tezos-signer import secret key ledger_tezos "ledger://<mnemonic>/ed25519/0'/0'" 
tezos-client import secret key ledger_tezos "ledger://<mnemonic>/ed25519/0'/0'" 
```

For each of these commands, you need to match the address displayed on the screen with the Ledger screen, then approve with the Ledger button.

You may replace the `0'/0'` value with `0'/1'` or more. This is useful when using the same setup with alphanet to use the same hardware but not the same keys.

Finally you need to set the ledger to bake for this key:

```
./tezos-client setup ledger to bake for ledger_tezos --main-chain-id NetXdQprcVkpaWU
```

Again you need to approve using the Ledger button.
