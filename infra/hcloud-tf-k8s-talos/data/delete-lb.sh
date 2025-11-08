#!/bin/bash
set -e -o pipefail

HCLOUD_TOKEN=$(az keyvault secret show --vault-name hegerdes --name hcloud-k8s-token | jq -r .value)
ING_LB_ID_1=$(curl -sLf -H "Authorization: Bearer $HCLOUD_TOKEN" "https://api.hetzner.cloud/v1/load_balancers?name=k8s-worker-ingress-lb" | jq .load_balancers[].id)

# Check if the load balancer ID is empty
if [ -z "$ING_LB_ID_1" ]; then
    echo "No load balancer found"
else
    echo "Deleting load balancer with ID: $ING_LB_ID_1"

    curl -sLf \
        -X DELETE \
        -H "Authorization: Bearer $HCLOUD_TOKEN" \
        "https://api.hetzner.cloud/v1/load_balancers/$ING_LB_ID_1"
fi

ING_LB_ID_2=$(curl -sLf -H "Authorization: Bearer $HCLOUD_TOKEN" "https://api.hetzner.cloud/v1/load_balancers?name=k8s-nginx-gateway-lb" | jq .load_balancers[].id)

# Check if the load balancer ID is empty
if [ -z "$ING_LB_ID_2" ]; then
    echo "No load balancer found"
else
    echo "Deleting load balancer with ID: $ING_LB_ID_2"

    curl -sLf \
        -X DELETE \
        -H "Authorization: Bearer $HCLOUD_TOKEN" \
        "https://api.hetzner.cloud/v1/load_balancers/$ING_LB_ID_2"
fi
