#!/bin/bash
set -e -o pipefail

echo "Waiting for cloud-init to finish..."
cloud-init status --wait

# setup requirements
echo "Installing packages..."
apt-get update -qq
apt-get install -qq --yes --no-install-recommends git python3-pip
pip3 install --user --break-system-packages --no-warn-script-location --no-cache-dir ansible jmespath
PATH=~/.local/bin:$PATH

if [ ! -d "playbooks" ]; then
  git clone --depth 1 https://github.com/hegerdes/ansible-playbooks.git playbooks
  cd playbooks
  git show --oneline -s
  cd ..
fi

# setup ansible play
echo "Running playbook..."
cd playbooks
echo "Vars:"
cat <<EOF >hostvars.yaml
k8s_crun_with_wasm: true
k8s_youki_with_wasm: true
k8s_cri: crun
k8s_containerd_variant: github
k8s_ensure_min_kernel_version: 6.12.*
k8s_external_cp_host: kubernetes.k8s.henrikgerdes.me
k8s_shared_api_server_endpoint: k8s-controlplane.local
k8s_absent_packages:
  - "wget"
  - "man-db"
  - "manpages"
  - "vim-tiny"
  - "vim"
  - "vim-runtime"
  - "libsodium23"
  - "vim-common"
  - "perl"
  - "htop"
  - "libgdbm-compat4"
  - "libgdbm6"
  - "libperl5.36"
  - "perl-modules-5.36"
  - "qemu-guest-agent"
  - "locales-all"
  - "linux-image-6.1.*"
EOF

printenv | sed 's/=/\: /g' | grep k8s >>hostvars.yaml
cat hostvars.yaml

cat <<EOF >pb_k8s_local.yml
- name: K8s-ClusterPrep
  hosts: localhost
  become: true
  gather_facts: true
  roles:
    - k8s/common
EOF

# Run playbook
ansible-playbook pb_k8s_local.yml --extra-vars "@hostvars.yaml" -v && cd

# Check if a reboot is required and reboot if necessary
if [ -f /var/run/reboot-required ]; then
  echo "Reboot required. Rebooting now..."
  rm -rf /var/run/reboot-required
  reboot && exit 0
else
  echo "Cleanup..."

  # Package cleanup
  rm -rf ~/.local/lib/python3.11 ~/.local/bin/ ~/.ansible ~/.cache/* ~/playbooks
  pip3 list -v
  apt-get purge --yes python3-pip python3-wheel git git-man liberror-perl wget man-db manpages vim-tiny qemu-guest-agent python3-google-auth linux-image-6.1.*
  apt list --installed
  apt-get autoremove --yes
  apt-get clean && apt-get autoclean

  # Cloud-init cleanup
  cloud-init clean --machine-id --seed --logs
  rm -rvf /var/lib/cloud/* /etc/machine-id /var/lib/dbus/machine-id /var/log/cloud-init*
  cloud-init status

  # Caches cleanup
  rm -rf /var/cache/apt/* /var/cache/debconf/* /var/cache/dpkg/* /var/cache/ansible/* /var/log/*.log* /tmp/* /var/tmp/* /usr/share/doc/*
  dd if=/dev/zero of=/mnt/zero.fill bs=1M || true
  rm -rf /mnt/zero.fill
  df -h
  sync
fi
