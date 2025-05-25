#!/bin/bash
set -e -o pipefail

AUTOSCALER_CONF=$(az keyvault secret list --vault-name hegerdes --only-show-errors | jq -r '.[] | select(.name == "k8s-hetzner-custer-autoscale-conf").name')

# Check if the load balancer ID is empty
if [ -z "$AUTOSCALER_CONF" ]; then
    echo "Secret k8s-hetzner-custer-autoscale-conf not found"
else
    echo "Deleting secret: $ING_LB_ID"
    az keyvault secret delete --vault-name hegerdes --name $AUTOSCALER_CONF
fi
