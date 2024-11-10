#!/bin/bash
set -e -o pipefail

echo "Waiting for cloud-init to finish..."
cloud-init status --wait

# setup reqirements
echo "Installing packages..."
apt-get update -qq
apt-get install -qq --yes --no-install-recommends git python3-pip
pip3 install --user --break-system-packages --no-warn-script-location --no-cache-dir ansible jmespath
PATH=~/.local/bin:$PATH
git clone --depth 1 https://github.com/hegerdes/ansible-playbooks.git playbooks

# setup anyible play
echo "Running playbook..."
cd playbooks
echo "Vars:"
echo "k8s_containerd_variant: github" >>hostvars.yaml
echo "k8s_shared_api_server_endpoint: k8s-controlplane.local" >>hostvars.yaml
printenv | sed 's/=/\: /g' | grep k8s >>hostvars.yaml
cat hostvars.yaml

cat <<EOF >pb_k8s_local.yml
- name: K8s-ClusterPreb
  hosts: localhost
  become: true
  gather_facts: true
  roles:
    - k8s/common
EOF

# run playbook
ansible-playbook pb_k8s_local.yml --extra-vars "@hostvars.yaml"

echo "Cleanup..." && cd ~
rm -rf /tmp/* ~/.local/lib/python3.11 .local/bin/ .ansible .cache playbooks
apt-get remove --yes python3-pip python3-wheel git
apt-get clean && apt-get autoclean
cloud-init clean --machine-id --seed --logs
rm -rvf /var/lib/cloud/instances /etc/machine-id /var/lib/dbus/machine-id /var/log/cloud-init*
cloud-init status
