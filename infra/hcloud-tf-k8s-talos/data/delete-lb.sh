#!/bin/bash
set -e -o pipefail

HCLOUD_TOKEN=$(az keyvault secret show --vault-name hegerdes --name hcloud-k8s-token | jq -r .value)
ING_LB_ID=$(curl -sLf -H "Authorization: Bearer $HCLOUD_TOKEN" "https://api.hetzner.cloud/v1/load_balancers?name=k8s-worker-ingress-lb" | jq .load_balancers[].id)

# Check if the load balancer ID is empty
if [ -z "$ING_LB_ID" ]; then
    echo "No load balancer found"
else
    echo "Deleting load balancer with ID: $ING_LB_ID"

    curl -sLf \
        -X DELETE \
        -H "Authorization: Bearer $HCLOUD_TOKEN" \
        "https://api.hetzner.cloud/v1/load_balancers/$ING_LB_ID"
fi
