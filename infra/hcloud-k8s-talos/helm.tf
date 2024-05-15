# ################# Helm #################
resource "time_sleep" "wait" {
  depends_on      = [data.talos_cluster_kubeconfig.this]
  create_duration = "120s"
}

resource "helm_release" "cni" {
  name       = "cilium"
  depends_on = [time_sleep.wait]

  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  namespace  = "kube-system"

  set {
    name  = "ipam.mode"
    value = "kubernetes"
  }
  set {
    name  = "kubeProxyReplacement"
    value = true
  }
  set {
    name  = "cgroup.hostRoot"
    value = "/sys/fs/cgroup"
  }
  set {
    name  = "k8sServiceHost"
    value = local.controlplane_internal_endpoint # talos proxy is localhost
  }
  set {
    name  = "k8sServicePort"
    value = 6443 # talos proxy is 7445
  }
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

  # values = [
  #   "${file("values.yaml")}"
  # ]
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress-controller"
  depends_on = [helm_release.cni]


  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx-ingress-controller"

  set {
    name  = "service.type"
    value = "ClusterIP"
  }
}
