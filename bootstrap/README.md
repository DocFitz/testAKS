# Bootstrap Process

## Prerequisites
- Azure CLI installed and logged in
- kubectl installed
- Cilium CLI installed

# a note on vnets....
# azure private endpoints use ips inside of vnets
# so ideally we never have a pod-cidr that overlaps
# with any other existing services.
# things can get messy with that, this includes things
# in the on-prem homelab!
# something like -  - 100.64.0.0/10 is a carrier grade ip
# and very likely to never overlap.


# need cilium cli, kubectl, aks-cli


# aks create
az aks create   --resource-group atomsResourceGroup   --name testcluster   --location centralus   --node-count 2   --node-vm-size Standard_D2ads_v7   --enable-managed-identity   --generate-ssh-keys   --network-plugin none   --service-cidr 10.0.0.0/16   --dns-service-ip 10.0.0.10   --pod-cidr 10.10.0.0/16   --network-policy none

# get cluster creds
az aks get-credentials \
  --resource-group atomsResourceGroup \
  --name testcluster

export CLUSTERPOOL_CIDR="192.168.0.0/16"
# cilium install
helm install cilium cilium/cilium   --namespace kube-system   --set aksbyocni.enabled=true   --set ipam.mode=cluster-pool --enable-node-port=true   --set ipam.operator.clusterPoolIPv4PodCIDRList="{${CLUSTERPOOL_CIDR}}"

# install argocd
kubectl create namespace argocd

kubectl apply --server-side \
  -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl apply -f bootstrap/app-of-apps.yaml

# get initial admin secret to change
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# forward ui to local
kubectl port-forward svc/argocd-server -n argocd 8080:443

# cert-manager config
need to set up issuer here.

# this should get fixed by helm chart stuff. if helm chart is working well then delete this
# upgrade helm with hubble stuff
helm upgrade cilium cilium/cilium   --namespace kube-system   --reuse-values   --set hubble.enabled=true   --set hubble.relay.enabled=true   --set hubble.ui.enabled=true





## One-Time Bootstrap

1. Create cluster with no CNI:

az aks create \
  --resource-group atomsResourceGroup \
  --name testcluster \
  --location centralus \
  --node-count 2 \
  --node-vm-size Standard_D2ads_v7 \
  --enable-managed-identity \
  --generate-ssh-keys \
  --network-plugin none \
  --service-cidr 10.96.0.0/16 \
  --dns-service-ip 10.96.0.10 \
  --pod-cidr 10.244.0.0/16
  --network-policy none

2. Install Cilium (required for pod networking):

#helm install [worked]
helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  --version 1.16.5 \
  -f bootstrap/cilium-values.yaml

cilium install \
  --version 1.16.5 \
  --set azure.resourceGroup=atomsResourceGroup \
  --set cluster.name=testcluster \
  --set cluster.id=1 \
  --set ipam.mode=cluster-pool \
  --set ipam.operator.clusterPoolIPv4PodCIDRList="{10.244.0.0/16}" \
  --set gatewayAPI.enabled=true \
  --set enableNodePort=true \
  --set bpf.masquerade=true \
  --set enableBBR=false

#checking for pod cidrs
kubectl get nodes -o jsonpath="{range .items[*]}{.metadata.name}{'  podCIDR='}{.spec.podCIDR}{'\n'}{end}"


cilium status --wait

#cilium uninstall
#cilium-secrets gets stuck sometimes
kubectl get namespace cilium-secrets -o json | \
  jq '.spec.finalizers = []' | \
  kubectl replace --raw /api/v1/namespaces/cilium-secrets/finalize -f -

#clean crds
kubectl get crd | grep cilium | awk '{print $1}' | xargs kubectl delete crd 2>/dev/null || true

#forsure
kubectl -n kube-system delete ds/cilium --ignore-not-found
kubectl -n kube-system delete deploy/cilium-operator --ignore-not-found
kubectl -n kube-system delete cm/cilium-config --ignore-not-found

#getting hubble enabled for real
helm upgrade cilium cilium/cilium -n kube-system -f cilium-values.yaml \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true

3. Install Gateway API CRDs:
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml


4. Bootstrap ArgoCD:

kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side


5. Deploy app-of-apps:

kubectl apply -f bootstrap/root-app.yaml


## What Happens Next

ArgoCD will:
- Take over management of Cilium (reconciling to Git values)
- Deploy cert-manager
- Deploy kyverno
- Manage itself via the argocd application

All future changes happen via Git commits.