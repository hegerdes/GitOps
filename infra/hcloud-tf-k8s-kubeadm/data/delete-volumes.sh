#!/bin/bash
set -e -o pipefail

HCLOUD_TOKEN=$(az keyvault secret show --vault-name hegerdes --name hcloud-k8s-token | jq -r .value)


VOLUME_IDS=$(curl -sLf -H "Authorization: Bearer $HCLOUD_TOKEN" "https://api.hetzner.cloud/v1/volumes" | jq .volumes[].id)

# Iterate over the list
for id in $VOLUME_IDS; do
  id=$(echo "$id" | tr -d '\r')
  echo "Deleting Volume: $id"
  # You can add your processing logic here

  curl -sLf -X DELETE -H "Authorization: Bearer $HCLOUD_TOKEN" "https://api.hetzner.cloud/v1/volumes/$id"
done



# # Check if the load balancer ID is empty
# if [ -z "$ING_LB_ID" ]; then
#     echo "No load balancer found"
# else
#     echo "Deleting load balancer with ID: $ING_LB_ID"

#     curl -sLf \
#         -X DELETE \
#         -H "Authorization: Bearer $HCLOUD_TOKEN" \
#         "https://api.hetzner.cloud/v1/load_balancers/$ING_LB_ID"
# fi
