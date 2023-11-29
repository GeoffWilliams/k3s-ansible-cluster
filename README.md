
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
* `k3s_version` is set in `inventory.yml` to install a specific version. This gives us repeatable deployments and not random versions
* For available versions check the [k3s releases page on github](https://github.com/k3s-io/k3s/releases)

## Install

```shell
ansible-playbook playbook/site.yml -i ../inventory.yml --vault-password-file ~/ansible_password.txt
```

Optionally limit the hosts processed, like this:

```shell
ansible-playbook playbook/site.yml -i ../inventory.yml --vault-password-file ~/ansible_password.txt -l k3s-worker-a
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
ansible-playbook playbook/upgrade.yml -i ../inventory.yml --vault-password-file ~/ansible_password.txt
```

## Longhorn

### Prereqs
* Run from top level of this repository
* [Ansible will format messages with `cowsay` if the package is installed](https://docs.ansible.com/ansible/latest/reference_appendices/faq.html#how-do-i-disable-cowsay). This amuses me.
* Mount propagation is on by default in k3s > ~0.10.0 so nothing needed to enable it

```shell
ansible-playbook playbook/longhorn_prereqs.yml -i inventory.yml
```

### Install with helm

[See instructions](https://longhorn.io/docs/1.5.3/deploy/install/install-with-helm/#installing-longhorn)

**docker hub may throttle downloads, be patient if you see `ImagePullBackOff`** errors, they should resolve eventually

After installation, create a simple Istio ingress to access the UI:

```shell
kubectl apply -f longhorn_ingress.yaml
```

* Adjust as needed
* Add the hostname for longhorn UI to your DNS
* This is a basic setup with no authentication to get you up and running, do something fancy with Istio or [follow the official guide](https://longhorn.io/docs/1.5.3/deploy/accessing-the-ui/longhorn-ingress/) to add access control

If you are able to access the UI, [go head and add volumes](https://longhorn.io/docs/1.5.3/volumes-and-nodes/)