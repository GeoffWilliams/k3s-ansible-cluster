
## Workstation setup

Install python first, [pyenv](https://github.com/pyenv/pyenv#installation) is the way to manage Python version, dont bother using the system or vendor python.

```shell
pip install ansible

# k3s provides an ansible playbook for managing K3s, easiest way to get lastest copy is to just download from git
git clone https://github.com/k3s-io/k3s-ansible
```

## Ping

```shell
ansible -m ping -i hosts.yml "*"
```

## Prepare the inventory file

1. Configure your server and agent specifics
2. Encrypt the token found on the master at `/var/lib/rancher/k3s/server/node-token` using `ansible-vault`

[How to use ansible-vault](https://www.declarativesystems.com/2023/11/29/ansible-vault.html)

## Using k3s-ansible

* You MUST run the ansible command from inside the `k3s-ansible` directory you checked out or you will get errors about missing roles
* These docs were prepared with version: `1e8bfb0d3967defe66929616f50a2f40d2470a87` from 2023-11-27
* `k3s_version` is set in `hosts.yml` to install a specific version. This gives us repeatable deployments and not random versions
* For available versions check the [k3s releases page on github](https://github.com/k3s-io/k3s/releases)

## Install

```shell
ansible-playbook playbook/site.yml -i ../hosts.yml --vault-password-file ~/ansible_password.txt
```

Optionally limit the hosts processed, like this:

```shell
ansible-playbook playbook/site.yml -i ../hosts.yml --vault-password-file ~/ansible_password.txt -l k3s-worker-a
```

## Upgrade

There is a separate playbook for upgrades:
* You must have previously run the `site.yml` playbook for the upgrade to succeed or you will get errors like this:
```
fatal: [cloud]: FAILED! => {"changed": true, "cmd": "/usr/local/bin/k3s-install.sh", "msg": "[Errno 2] No such file or directory: b'/usr/local/bin/k3s-install.sh'", "rc": 2, "stderr": "", "stderr_lines": [], "stdout": "", "stdout_lines": []}
```
* [Follow the upgrade rules](https://docs.k3s.io/upgrades), eg master first then agents
* You can choose to upgrade nodes one by one (`-l ...`) or just let rip

```shell
ansible-playbook playbook/upgrade.yml -i ../hosts.yml --vault-password-file ~/ansible_password.txt
```

## Istio

* [instructions](https://istio.io/latest/docs/setup/install/helm/)
* [charts](https://github.com/istio/istio/tree/master/manifests/charts)
* more docs: https://tetrate.io/blog/istio-ingressclass-controller-with-helm/

```shell
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

kubectl create namespace istio-system

helm upgrade --install istio-base istio/base -n istio-system --set defaultRevision=default --version=1.20.2

helm upgrade --install istiod istio/istiod -n istio-system --wait --version=1.20.2 --values istiod_values.yaml
kubectl create namespace istio-ingress

helm upgrade --install istio-ingressgateway istio/gateway -n istio-ingress --values istio_gateway_values.yaml --version=1.20.2
```

gateways:

```shell
kubectl create -n istio-ingress secret tls tls-wildcard   --key=/home/geoff/ca/wildcard.lan.asio.key   --cert=/home/geoff/ca/wildcard.lan.asio.pem
kubectl apply -f gateway.yaml
```

## Longhorn

[Chart sourcecode](https://github.com/longhorn/charts)

### Prereqs
* Run from top level of this repository
* [Ansible will format messages with `cowsay` if the package is installed](https://docs.ansible.com/ansible/latest/reference_appendices/faq.html#how-do-i-disable-cowsay). This amuses me.
* Mount propagation is on by default in k3s > ~0.10.0 so nothing needed to enable it

```shell
ansible-playbook playbook/longhorn_prereqs.yml -i hosts.yml
```

### Install with helm

[See instructions](https://longhorn.io/docs/1.5.3/deploy/install/install-with-helm/#installing-longhorn)

To adjust where longhorn stores data, adjust the helm install command:

```shell
helm repo add longhorn https://charts.longhorn.io
helm repo update

helm upgrade --install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace --version 1.5.3 --values=longhorn_values.yaml
```

* This will let you store data on some other volume than the default `/var/lib/longhorn/` which is normally on the root partition.
* This is good if you want to attach an extra SSD at `/data`.
* Symlinks will not work without special attention as link will not propagate insdie of kubernetes. If you have "special snowflake" server that needs data at a different location to the others, its easier to just edit the node in the UI
* If you need to upgrade storage with extra SSDs they can be mounted to this directory and the old files moved onto the new partition

**docker hub may throttle downloads, be patient if you see `ImagePullBackOff`** errors, they should resolve eventually

After installation, create a simple Istio ingress to access the UI:

```shell
kubectl apply -f longhorn_ingress.yaml
```

* Adjust as needed
* Add the hostname for longhorn UI to your DNS
* This is a basic setup with no authentication to get you up and running, do something fancy with Istio or [follow the official guide](https://longhorn.io/docs/1.5.3/deploy/accessing-the-ui/longhorn-ingress/) to add access control

If your able to access the UI your in business.

### Testing Longhorn

* [Follow the guide](https://longhorn.io/docs/1.5.3/volumes-and-nodes/)
* `longhorn` storage class is already created after helm install
* You just need to create PVCs to access the storage needed

Create a test volume and make sure data shows up in the right place (adapted from the guide):

```shell
kubectl create -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/examples/pod_with_pvc.yaml

# wait some seconds...
kubectl exec -ti volume-test -- sh
```

Inside the container, create a 1GB test file:

```shell
dd if=/dev/zero of=/data/atest bs=1M count=1000
```

Now look on the node filesystems, you should see ~1GB usage with `du -sh` in the data directory which will either be the default of `/var/lib/longhorn` or a custom directory like `/data/longhorn` if this was set when deploying with helm.

Also click around the longhorn UI and inspect the volume.

When satisfied its working, delete the pod:

```shell
kubectl delete -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/examples/pod_with_pvc.yaml
```

With the default retention settings this will destroy the pod, the PVC and the actual data on disk. You can prove this by re-running the previous `du` command.

If this works you can start using longhorn for your storage needs.

### Migrating data

Now longhorn is setup, there is probably some old data that needs to be imported, so follow these steps:

Source: https://forums.rancher.com/t/move-existing-data-into-longhorn/20017/2

> 1. You have an old PVC with old volume data
> 2. Create new PVC using longhorn StorageClass
> 3. Deploy this [example data migration pod](https://github.com/longhorn/longhorn/blob/master/examples/data_migration.yaml) to copy the data from old PVC to the new PVC.

There are also a few other ways of moving data on the same forum thread.

### Uninstalling longhorn

To reset your lab:

* Dont just delete the helm chart it wont work. This is to avoid accidentally destroying important storage
* [Follow the guide](https://longhorn.io/docs/1.5.3/deploy/uninstall/). There is a command to patch the delete confirmation setting

```shell
kubectl -n longhorn-system patch -p '{"value": "true"}' --type=merge lhs deleting-confirmation-flag
helm uninstall --namespace longhorn-system longhorn
```

## Harbor

[Install via helm: instructions](https://goharbor.io/docs/2.10.0/install-config/harbor-ha-helm/)

### Install helm chart

[Chart sourcescode](https://github.com/goharbor/harbor-helm)


```shell
helm repo add harbor https://helm.goharbor.io
helm repo update

kubectl create namespace harbor
kubectl label namespace harbor istio-injection=enabled

helm upgrade --install harbor harbor/harbor --namespace harbor --version 1.14.0 --values=harbor_values.yaml --set harborAdminPassword=$(cat ~/harbor_admin_password.txt)
```

## Uninstall

```shell
helm uninstall -n harbor harbor
```