#!/bin/bash
set -xo pipefail

tar -czpf /tmp/rootfs-k8s-debian-$(uname -m).tar.gz \
  --exclude=/tmp \
  --exclude=/proc \
  --exclude=/sys \
  --exclude=/dev \
  --exclude=/run \
  --exclude='*.sock' \
  --one-file-system \
  / 2>/dev/null


# Check if aws cli is installed
if ! command -v aws > /dev/null; then
  echo "Installing aws-cli"
  if command -v apk > /dev/null; then
    apk add --no-cache aws-cli > /dev/null
  else
    curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "/tmp/awscliv2.zip"
    unzip /tmp/awscliv2.zip -d /tmp > /dev/null
    /tmp/aws/install > /dev/null
  fi
fi

aws --version
aws s3 cp /tmp/rootfs-k8s-debian-$(uname -m).tar.gz s3://my-bucket
rm /tmp/rootfs-k8s-debian-$(uname -m).tar.gz
