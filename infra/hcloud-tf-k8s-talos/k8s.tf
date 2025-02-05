# ################# Helm #################
resource "time_sleep" "wait" {
  depends_on      = [talos_cluster_kubeconfig.this]
  create_duration = "90s"
}

resource "helm_release" "cni" {
  name  = "cilium"
  count = fileexists(local_sensitive_file.kubeconf.filename) ? 1 : 0

  repository      = "https://helm.cilium.io/"
  wait            = false
  chart           = "cilium"
  namespace       = "kube-system"
  upgrade_install = true
  values = [try(templatefile(var.cilium_values_path, {
    ipv6_enabled = local.ipv6_enabled
  }), "")]

  depends_on = [time_sleep.wait, module.node_pools, module.loadbalancer, local_sensitive_file.kubeconf]

  set {
    name  = "cluster.name"
    value = var.cluster_name
  }
}

resource "helm_release" "argocd" {
  name  = "argocd"
  count = fileexists(local_sensitive_file.kubeconf.filename) ? 1 : 0

  namespace        = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  upgrade_install  = true
  create_namespace = true

  values     = [try(file(var.argo_values_path), "")]
  depends_on = [time_sleep.wait, module.node_pools, module.loadbalancer, helm_release.cni]
}
