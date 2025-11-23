#!/bin/bash
set -e -o pipefail

HCLOUD_TOKEN=$(az keyvault secret show --vault-name hegerdes --name hcloud-k8s-token | jq -r .value)
ING_LB_IDS=$(curl -sLf -H "Authorization: Bearer $HCLOUD_TOKEN" "https://api.hetzner.cloud/v1/load_balancers?label_selector=hcloud-ccm/service-uid" | jq .load_balancers[].id)


# Iterate over the list
for id in $ING_LB_IDS; do
  id=$(echo "$id" | tr -d '\r')
  echo "Deleting Loadbalancer: $id"
  # You can add your processing logic here

  curl -sLf -X DELETE -H "Authorization: Bearer $HCLOUD_TOKEN" "https://api.hetzner.cloud/v1/load_balancers/$id"
done
