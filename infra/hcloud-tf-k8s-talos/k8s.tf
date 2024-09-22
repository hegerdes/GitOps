# ################# Helm #################
resource "time_sleep" "wait" {
  depends_on      = [talos_cluster_kubeconfig.this]
  create_duration = "90s"
}

resource "helm_release" "cni" {
  name       = "cilium"
  depends_on = [time_sleep.wait, module.node_groups, module.loadbalancer]

  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  namespace  = "kube-system"
  values     = [try(file(var.cilium_values_path), "")]

  set {
    name  = "cluster.name"
    value = var.cluster_name
  }
  # set {
  #   name  = "k8sServiceHost"
  #   value = local.cp_internal_endpoint # talos proxy is localhost
  # }
  # set {
  #   name  = "k8sServicePort"
  #   value = 6443 # talos proxy is 7445
  # }
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
