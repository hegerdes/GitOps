#!/bin/bash
set -e -o pipefail

TARGET_NAMESPACE="sealed-secrets"
SEALED_SECRETS_PREFIX="sealkey"
SELECTOR="sealedsecrets.bitnami.com/sealed-secrets-key=active"
GO_TEMPLATE='{{range .items}}{{.metadata.namespace}}/{{.metadata.name}}{{"\n"}}{{end}}'

echo "Listing all active sealed secrets in the cluster:"
SEAL_KEYS=$(kubectl get secrets -A --selector "${SELECTOR}" -o go-template="$GO_TEMPLATE")

# Sync each secret to the target namespace
for SECRET in $SEAL_KEYS; do
  echo "Processing key-pair: $SECRET"
    SECRET_NAMESPACE=$(echo $SECRET | cut -d'/' -f1)
    SECRET_NAME=$(echo $SECRET | cut -d'/' -f2)
    if [ "$SECRET_NAMESPACE" = "$TARGET_NAMESPACE" ]; then
      echo "Secret $SECRET is the target namespace $TARGET_NAMESPACE. Skipping."
      continue
    fi
    kubectl get secret "$SECRET_NAME" -n "$SECRET_NAMESPACE" -o json \
        | jq '.metadata.namespace = "'$TARGET_NAMESPACE'"' \
        | jq '.metadata.name = "'$SEALED_SECRETS_PREFIX-$SECRET_NAMESPACE-$SECRET_NAME'"' \
        | jq '.metadata.annotations["automation.hegerdes/source-ns"] = "'$SECRET_NAMESPACE'"' \
        | jq '.metadata.annotations["automation.hegerdes/source-name"] = "'$SECRET_NAME'"' \
        | jq 'del(.metadata.annotations["kubectl.kubernetes.io/last-applied-configuration"])' \
        | jq 'del(.metadata.resourceVersion)' \
        | jq 'del(.metadata.uid)' \
        | kubectl apply -f -
done

# Remove secrets in target namespace if the source secret does not exist anymore
for SECRET in $(kubectl get secret -n "$TARGET_NAMESPACE" --selector "${SELECTOR}" -o name); do
  echo "Processing target key-pair: $SECRET"
  ORI_SECRET_NAME=$(kubectl get -n "$TARGET_NAMESPACE" "$SECRET" -o json | jq -r '.metadata.annotations["automation.hegerdes/source-name"]')
  ORI_SECRET_NS=$(kubectl get -n "$TARGET_NAMESPACE" "$SECRET" -o json | jq -r '.metadata.annotations["automation.hegerdes/source-ns"]')
  if ! kubectl get secret $ORI_SECRET_NAME -n $ORI_SECRET_NS >/dev/null 2>&1; then
    echo "The source for secret does not exist anymore. Deleting it from $TARGET_NAMESPACE"
        kubectl delete -n "$TARGET_NAMESPACE" "$SECRET"
    fi
done
