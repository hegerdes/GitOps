# GitOps

## Content
This repo contains a collection of tools and examples about the GitOps operation mode, mostly based on Kubernetes.
It is separated on two categories: Infrastructure and Services

## GitOps Infrastructure
In the [infra](/infra) directory are infrastructure as code (IaC) setups to repeatedly create consistent compute resources. It includes:
 * hcloud Packer Script for Talos
 * hcloud Packer Script for generic operating systems
 * hcloud Terraform/OpenTofu declarations for fully day2 managed Talos via node groups
 * hcloud Terraform/OpenTofu declarations for generic operating systems via node groups

## GitOps Services
In the [k8s-apps](/k8s-apps) and [k8s-cluster-hcloud-critical](/k8s-cluster-hcloud-critical) directory are ArgoCD Applications and generic Kubernetes Manifests vor various Kubernetes based services. Including:
 * argocd
 * cert-manager
 * external-dns-aws
 * external-dns-azure
 * external-dns-cloudflare
 * external-secrets
 * gitlab-agent
 * grafana-flow-agent
 * hcloud
 * metrics
 * nginx-ingress
 * oauth2-proxy
 * secret-store-csi
 * tailscale

## Notes
Either with only these resources (for Talos) or with the help of my [hegerdes/ansible-playbooks](https://github.com/hegerdes/ansible-playbooks) one can create fully working and customizable Kubernetes setups that are reproducible and maintainable.
