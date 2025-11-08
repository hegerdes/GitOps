#!/bin/bash
set -e -o pipefail

HCLOUD_TOKEN=$(az keyvault secret show --vault-name hegerdes --name hcloud-k8s-token | jq -r .value)
CAS_VOLUME_IDS=$(curl -sLf -H "Authorization: Bearer $HCLOUD_TOKEN" "https://api.hetzner.cloud/v1/volumes?label_selector=managed-by=csi-driver" | jq .volumes[].id)

# Check if the load balancer ID is empty
if [ -z "$CAS_VOLUME_IDS" ]; then
    echo "No volumes found"
else
    echo -e "Found volumes IDs: \n$CAS_VOLUME_IDS"
    echo -e "$CAS_VOLUME_IDS" | while IFS= read -r K8s_VOLUME_ID; do
        K8s_VOLUME_ID=$(echo "$K8s_VOLUME_ID" | tr -d '\r')
        echo "Deleting volume ID: $K8s_VOLUME_ID"
        curl -sLf \
            -X DELETE \
            -H "Authorization: Bearer $HCLOUD_TOKEN" \
            "https://api.hetzner.cloud/v1/volumes/$K8s_VOLUME_ID"
    done
fi
