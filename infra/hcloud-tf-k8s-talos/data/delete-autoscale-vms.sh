#!/bin/bash
set -e -o pipefail

HCLOUD_TOKEN=$(az keyvault secret show --vault-name hegerdes --name hcloud-k8s-token | jq -r .value)
CAS_SERVER_IDS=$(curl -sLf -H "Authorization: Bearer $HCLOUD_TOKEN" "https://api.hetzner.cloud/v1/servers?label_selector=hcloud/node-group" | jq .servers[].id)

# Check if the load balancer ID is empty
if [ -z "$CAS_SERVER_IDS" ]; then
    echo "No servers found"
else
    echo -e "Found server IDs: \n$CAS_SERVER_IDS"
    echo -e "$CAS_SERVER_IDS" | while IFS= read -r CAS_SERVER_ID; do
        CAS_SERVER_ID=$(echo "$CAS_SERVER_ID" | tr -d '\r')
        echo "Deleting server ID: $CAS_SERVER_ID"
        curl -sLf \
            -X DELETE \
            -H "Authorization: Bearer $HCLOUD_TOKEN" \
            "https://api.hetzner.cloud/v1/servers/$CAS_SERVER_ID"
    done
fi
