#!/bin/bash
set -e -o pipefail

echo "Waiting for cloud-init to finish..."
cloud-init status --wait

if [ -f /root/ansible-setup.done ]; then
  rm -rf /root/ansible-setup.done
  exit 0
fi

HC_NET_UTILS="https://packages.hetzner.com/hcloud/deb/hc-utils_0.0.6-1_all.deb"
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
  - "less"
  - "xdg-user-dirs"
  - "whiptail"
  - "nano"
  - "bash-completion"
  - "bind9-dnsutils"
  - "htop"
  - "libgdbm-compat4"
  - "libgdbm6"
  - "libperl5.36"
  - "rsync"
  - "perl-modules-5.36"
  - "acl"
  - "netcat-traditional"
  - "python3-reportbug"
  - "qemu-guest-agent"
  - "locales-all"
  - "linux-image-6.1.*"
  - "cron"
  - "cron-daemon"
  - "keyboard-configuration"
  - "console-setup"
  - "sudo"
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
  apt-get purge --yes python3-pip python3-wheel curl git git-man liberror-perl wget man-db manpages vim-tiny qemu-guest-agent python3-google-auth linux-image-6.1.*
  apt list --installed
  apt-get autoremove --yes
  python3 -c "import urllib.request; urllib.request.urlretrieve(\"$HC_NET_UTILS\", \"/tmp/hc-utils.deb\")"
  apt-get install -qq --yes --no-install-recommends /tmp/hc-utils.deb
  apt-get clean && apt-get autoclean
  rm -rf /usr/bin/crictl

  # Cloud-init cleanup
  cloud-init clean --machine-id --seed --logs
  rm -rvf /var/lib/cloud/* /etc/machine-id /var/lib/dbus/machine-id /var/log/cloud-init*
  cloud-init status

  # Caches cleanup
  systemctl stop systemd-journald
  rm -rf /var/cache/apt/* /var/lib/apt/lists/* /var/cache/debconf/* /var/cache/dpkg/* /var/cache/ansible/* /var/log/*.log* /tmp/* /var/tmp/* /var/log/journal/* /usr/share/doc/* /usr/share/man/*
  find /usr/lib/python3 -type f -name "*.pyc" -delete
  find /usr/share/locale/ -maxdepth 1 -type d ! -name 'en' ! -name 'en_US' ! -name 'en_US.UTF-8' -exec rm -rf {} +

  dd if=/dev/zero of=/mnt/zero.fill bs=1M || true
  rm -rf /mnt/zero.fill
  systemctl start systemd-journald
  journalctl --vacuum-time=1s
  df -h
  sync
fi

echo "marker file" >/root/ansible-setup.done
