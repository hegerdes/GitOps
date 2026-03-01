Hennes Kubernes Service

Tasks:
 * Create deploymets for:
  * kube-apiserver ✅
  * kube-controller ✅
  * etcd ✅
 * Create certs - hacky ✅
 * Ensure communication ✅
 * Refine Deployments ✅
 * Create certs - prod ✅
 * GitOps:
   * HKS ✅
   * Slave Cluster
 * Generate join token
   * POC ✅
   * Service-Controller
 * Join Worker
 * Ensure Connectivity
   * Worker -> CP
   * CP -> Worker
 * Worker Apps
   * CoreDNS
   * Cilium


```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.19.2/cert-manager.yaml
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.2.3/manifests/install.yaml
# kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/experimental-install.yaml
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/experimental?ref=v2.3.0" | kubectl apply -f - --server-side
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric --create-namespace -n nginx-gateway --set nginxGateway.gwAPIExperimentalFeatures.enable=true

kaf argo-hks-shared.yaml
kaf ../../k8s-cluster-hcloud-critical/argo-external-secrets.yml
kaf ../argo-nginx-gateway-fabric.yml
kaf argo-appset-hks.yaml
```
