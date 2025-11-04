#!/bin/bash

# set -e
HELM_TEMPLATE_DST="/tmp/k8s-check"
mkdir -p $HELM_TEMPLATE_DST

######### Raw kustomize setup #########
echo "Linting kustomize manifests..."
find . -type f -name "kustomization.yaml" -exec dirname {} \; | parallel --joblog kustomize.log -k kubectl kustomize --enable-helm {} | kubeconform -summary -ignore-missing-schemas

######### Raw manifests #########
echo "Linting raw manifests..."
find . -type f \( -name "*.yaml" -o -name "*.yml" \) \
  ! -iname "kustomization.yaml" ! -iname "kustomization.yml" \
  -exec grep -q "apiVersion" {} \; \
  -exec grep -q "kind" {} \; \
  -print 2>/dev/null | parallel --joblog manifests.log -k yq eval-all '.' | kubeconform -summary -ignore-missing-schemas
  -print 2>/dev/null | yq eval-all '.' | kubeconform -summary -ignore-missing-schemas


######### ArgoCD Application Helm charts #########
echo "Linting ArgoCD Application Helm charts..."
ARGO_APPS=$(find . -type f \( -name "*.yaml" -o -name "*.yml" \) \
  -exec grep -q "^kind: *Application" {} \; \
  -exec grep -q "^apiVersion: *argoproj.io/v1" {} \; \
  -exec grep -q "helm:" {} \; \
  -print)

helm_repo_add() {
    local ARGO_HELM_CHART="$1"
    local ARGO_HELM_REPO="$2"
    if [[ "$ARGO_HELM_CHART" != "null" && "$ARGO_HELM_REPO" != "null" && "$ARGO_HELM_REPO" == http* ]]; then
        helm repo add $ARGO_HELM_CHART $ARGO_HELM_REPO --force-update
    fi
}

helm_chart_template() {
    local ARGO_HELM_APP="$1"
    local ARGO_HELM_CHART="$2"
    local ARGO_HELM_RELEASE="$3"
    local ARGO_HELM_VERSION="$4"
    local ARGO_HELM_OCI_CHART_URI="$5"
    local ARGO_HELM_CHART_URI=""

    # If OCI Chart or not
    if [ -z "${ARGO_HELM_OCI_CHART_URI}" ]; then
        ARGO_HELM_CHART_URI="$ARGO_HELM_CHART/$ARGO_HELM_CHART"
    else
        ARGO_HELM_CHART_URI="oci://$ARGO_HELM_OCI_CHART_URI/$ARGO_HELM_CHART"
    fi

    helm template $ARGO_HELM_RELEASE $ARGO_HELM_CHART_URI \
        --version $ARGO_HELM_VERSION \
        --values /tmp/${ARGO_HELM_RELEASE}-values.yaml > $HELM_TEMPLATE_DST/$ARGO_HELM_APP-$ARGO_HELM_RELEASE-rendered.yaml
}

echo "Adding repos..."
for app in $ARGO_APPS; do

    if $(yq eval '(.spec.source) != null' $app) = "true"; then
        ARGO_HELM_CHART=$(yq eval '.spec.source.chart' $app)
        ARGO_HELM_REPO=$(yq eval '.spec.source.repoURL' $app)
        helm_repo_add "$ARGO_HELM_CHART" "$ARGO_HELM_REPO"

    elif $(yq eval '(.spec.sources) != null' $app) = "true"; then
        yq -o=json '.spec.sources[]' $app | jq -c '.' | while read -r item; do
            ARGO_HELM_CHART=$(echo "${item}" | jq -r '.chart')
            ARGO_HELM_REPO=$(echo "${item}" | jq -r '.repoURL')
            helm_repo_add "$ARGO_HELM_CHART" "$ARGO_HELM_REPO"
        done
    fi
done

echo "Updating helm repos"
helm repo update

for app in $ARGO_APPS; do
    echo "Linting ArgoCD Application: $app"

    if $(yq eval '(.spec.source) != null' $app) = "true"; then
        ARGO_HELM_CHART=$(yq eval '.spec.source.chart' $app)
        ARGO_HELM_VERSION=$(yq eval '.spec.source.targetRevision' $app)
        ARGO_HELM_REPO=$(yq eval '.spec.source.repoURL' $app)
        ARGO_HELM_OCI_CHART_URI=$([[ "$ARGO_HELM_REPO" != http* ]] && echo $ARGO_HELM_REPO)
        ARGO_HELM_RELEASE=$(yq eval '.spec.source.helm.releaseName' $app)

        if $(yq eval '(.spec.source.helm.valuesObject) != null' $app) = "true"; then
            echo "$app - found valuesObject parameter"
            yq '.spec.source.helm.valuesObject' $app > /tmp/${ARGO_HELM_RELEASE}-values.yaml

            # Render the helm chart
            helm_chart_template $(basename $app | sed -E 's/\.ya?ml$//') $ARGO_HELM_CHART $ARGO_HELM_RELEASE $ARGO_HELM_VERSION $ARGO_HELM_OCI_CHART_URI

        elif $(yq eval '(.spec.source.helm.values) != null' $app) = "true"; then
            echo "$app - found values parameter"
            yq '.spec.source.helm.values' $app > /tmp/${ARGO_HELM_RELEASE}-values.yaml

            # Render the helm chart
            helm_chart_template $(basename $app | sed -E 's/\.ya?ml$//') $ARGO_HELM_CHART $ARGO_HELM_RELEASE $ARGO_HELM_VERSION

        elif $(yq eval '(.spec.source.helm.valueFiles) != null' $app) = "true"; then
            echo "$app - found valueFiles parameter"
            echo "# Values for $app" > /tmp/${ARGO_HELM_RELEASE}-values.yaml
            yq -o=json '.spec.source.helm.valueFiles[]' $app | jq -r -c '.' | while read -r item; do
                VALUES_FILE_NAME=$(basename $item)
                echo "$app - processing value file: ${VALUES_FILE_NAME}"
                if find . -type f -name "$VALUES_FILE_NAME" | grep -q .; then
                    cat $(find . -type f -name "$VALUES_FILE_NAME") >> /tmp/${ARGO_HELM_RELEASE}-values.yaml
                else
                    echo "$app - value file: ${VALUES_FILE_NAME} not found. Skipping"
                fi
            done

            # Render the helm chart
            helm_chart_template $(basename $app | sed -E 's/\.ya?ml$//') $ARGO_HELM_CHART $ARGO_HELM_RELEASE $ARGO_HELM_VERSION
        else
            echo "$app - No supported values parameter found. Using defaults"
        fi

    elif $(yq eval '(.spec.sources) != null' $app) = "true"; then
        echo "$app - Multiple sources found. Running on helm check on each one"
        SOURCE_INDEX=0
        yq -o=json '.spec.sources[]' $app | jq -r -c '.' | while read -r item; do
            ARGO_HELM_CHART=$(echo $item | yq eval '.chart')
            ARGO_HELM_VERSION=$(echo $item | yq eval '.targetRevision')
            ARGO_HELM_RELEASE=$(echo $item | yq eval '.helm.releaseName')-$SOURCE_INDEX
            ARGO_HELM_REPO=$(echo $item | yq eval '.repoURL')
            ARGO_HELM_OCI_CHART_URI=$([[ "$ARGO_HELM_REPO" != http* ]] && echo $ARGO_HELM_REPO)

            if $(echo $item | yq eval '(.helm.valuesObject) != null') = "true"; then
                echo "$app - found valuesObject parameter in source index $SOURCE_INDEX"
                echo $item | yq '.helm.valuesObject' > /tmp/${ARGO_HELM_RELEASE}-values.yaml

                # Render the helm chart
                helm_chart_template $(basename $app | sed -E 's/\.ya?ml$//') $ARGO_HELM_CHART $ARGO_HELM_RELEASE $ARGO_HELM_VERSION $ARGO_HELM_OCI_CHART_URI
                SOURCE_INDEX=$((SOURCE_INDEX + 1))

            elif $(echo $item | yq eval '(.helm.values) != null') = "true"; then
                echo "$app - found values parameter in source index $SOURCE_INDEX"
                echo $item | yq '.helm.values' > /tmp/${ARGO_HELM_RELEASE}-values.yaml

                # Render the helm chart
                helm_chart_template $(basename $app | sed -E 's/\.ya?ml$//') $ARGO_HELM_CHART $ARGO_HELM_RELEASE $ARGO_HELM_VERSION $ARGO_HELM_OCI_CHART_URI
                SOURCE_INDEX=$((SOURCE_INDEX + 1))

            elif $(echo $item | yq eval '(.helm.valueFiles) != null') = "true"; then
                echo "$app - found valueFiles parameter in source index $SOURCE_INDEX"
                echo "# Values for $app" > /tmp/${ARGO_HELM_RELEASE}-values.yaml
                echo $item | yq -o=json '.helm.valueFiles[]' | jq -r -c '.' | while read -r item; do
                    VALUES_FILE_NAME=$(basename $item)
                    echo "$app - processing value file: ${VALUES_FILE_NAME}"
                    if find . -type f -name "$VALUES_FILE_NAME" | grep -q .; then
                        cat $(find . -type f -name "$VALUES_FILE_NAME") >> /tmp/${ARGO_HELM_RELEASE}-values.yaml
                    else
                        echo "$app - value file: ${VALUES_FILE_NAME} not found. Skipping"
                    fi
                done

                # Render the helm chart
                helm_chart_template $(basename $app | sed -E 's/\.ya?ml$//') $ARGO_HELM_CHART $ARGO_HELM_RELEASE $ARGO_HELM_VERSION $ARGO_HELM_OCI_CHART_URI
                SOURCE_INDEX=$((SOURCE_INDEX + 1))

            else
                echo "$app - not a helm source or no supported values parameter found. Skipping"
            fi
        done
    fi
done

find $HELM_TEMPLATE_DST -type f -name "*.yaml" | parallel --joblog helm.log -k kubeconform -summary -ignore-missing-schemas

cat *.log
rm *.log
