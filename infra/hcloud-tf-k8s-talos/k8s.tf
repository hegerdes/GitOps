# ################# Helm #################
resource "time_sleep" "wait" {
  depends_on      = [data.talos_cluster_kubeconfig.this]
  create_duration = "90s"
}

resource "helm_release" "cni" {
  name       = "cilium"
  depends_on = [time_sleep.wait, module.node_groups, module.loadbalancer]

  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  namespace  = "kube-system"

  set {
    name  = "cluster.name"
    value = var.cluster_name
  }
  set {
    name  = "ipam.mode"
    value = "kubernetes"
  }
  set_list {
    name  = "ipam.operator.clusterPoolIPv4PodCIDRList"
    value = ["10.244.0.0/16"]
  }
  set {
    name  = "hostFirewall.enabled"
    value = true
  }
  set {
    name  = "bandwidthManager.enabled"
    value = true
  }
  set {
    name  = "bpf.masquerade"
    value = true
  }
  # set {
  #   name  = "bgp.enabled"
  #   value = true
  # }
  # set {
  #   name  = "bgp.announce.loadbalancerIP"
  #   value = true
  # }
  set {
    name  = "kubeProxyReplacement"
    value = true
  }
  set {
    name  = "loadBalancer.algorithm"
    value = "maglev"
  }
  set {
    name  = "loadBalancer.serviceTopology"
    value = true
  }
  set {
    name  = "hubble.enabled"
    value = true
  }
  set {
    name  = "hubble.relay.enabled"
    value = true
  }
  # set {
  #   name  = "routingMode"
  #   value = "native"
  # }
  # set {
  #   name  = "ipv4NativeRoutingCIDR"
  #   value = hcloud_network.k8s_network.ip_range
  # }
  set {
    name  = "cgroup.hostRoot"
    value = "/sys/fs/cgroup"
  }
  set {
    name  = "k8sServiceHost"
    value = "localhost" # talos proxy is localhost
  }
  set {
    name  = "k8sServicePort"
    value = 7445 # talos proxy is 7445
  }
  # set {
  #   name  = "k8sServiceHost"
  #   value = local.cp_internal_endpoint # talos proxy is localhost
  # }
  # set {
  #   name  = "k8sServicePort"
  #   value = 6443 # talos proxy is 7445
  # }
  set {
    name  = "cgroup.autoMount.enabled"
    value = false
  }
  set_list {
    name  = "securityContext.capabilities.ciliumAgent"
    value = ["CHOWN", "KILL", "NET_ADMIN", "NET_RAW", "IPC_LOCK", "SYS_ADMIN", "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID"]
  }
  set_list {
    name  = "securityContext.capabilities.cleanCiliumState"
    value = ["NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE"]
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  create_namespace = true

  values     = [try(file(var.argo_values_path), "")]
  depends_on = [time_sleep.wait, module.node_groups, module.loadbalancer, helm_release.cni]
}
