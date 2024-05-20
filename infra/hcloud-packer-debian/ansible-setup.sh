#!/bin/bash
set -e -o pipefail

echo "waiting for cloud-init to finish..."
cloud-init status --wait

echo "installing packages..."
apt-get update
apt-get install --yes --no-install-recommends wget git python3-pip
pip3 install --user --break-system-packages --no-warn-script-location --no-cache-dir ansible jmespath
PATH=~/.local/bin:$PATH
git clone --depth 1 https://github.com/hegerdes/ansible-playbooks.git playbooks

echo "running playbook..."
echo "vars:"
cd playbooks
printenv | sed 's/=/\: /g' | grep k8s | tee -a hostvars.yaml
ansible-playbook pb_k8s_local.yml --extra-vars "@hostvars.yaml"
cd ~

echo "cleanup..."
rm -rf /tmp/* ~/.local/lib/python3.11 .local/bin/ .ansible .cache playbooks
apt-get remove --yes python3-pip python3-wheel
apt-get clean && apt-get autoclean
cloud-init clean --machine-id --seed --logs
rm -rvf /var/lib/cloud/instances /etc/machine-id /var/lib/dbus/machine-id /var/log/cloud-init*
cloud-init status
