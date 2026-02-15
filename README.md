# explanation of repo
/clusters/env/apps/*.yaml are the child applications, i.e. specific values we want for that environment. 
/apps has all of the source manifest information.
root-app.yaml in the dev cluster points to clusters/dev/apps
we are trying to use a helm first approach, for those apps that use helm - use helm first
only use kustomization if there isnt a helm chart available or it wont work.

chart.yaml is a helm wrapper chart that references the upstream chart. the values file is referenced in the relevant clusters/env/apps/app.yaml file. there youll see both the chart and the values file.

## bootstrap
# aks create
az aks create \
  --resource-group atomsResourceGroup \
  --name testcluster \
  --location centralus \
  --node-count 2 \
  --node-vm-size Standard_D2ads_v7 \
  --enable-managed-identity \
  --generate-ssh-keys \
  --network-plugin none \
  --service-cidr 10.0.0.0/16 \
  --dns-service-ip 10.0.0.10 \
  --pod-cidr 192.168.0.0/16 \
  --network-policy none

# get cluster creds
az aks get-credentials \
  --resource-group atomsResourceGroup \
  --name testcluster

export CLUSTERPOOL_CIDR="192.168.0.0/16"
# cilium install
helm install cilium cilium/cilium   --namespace kube-system   --set aksbyocni.enabled=true   --set ipam.mode=cluster-pool --set ipam.operator.clusterPoolIPv4PodCIDRList="{${CLUSTERPOOL_CIDR}}"

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



# deletion stuff

//delete cluster if needed
az aks delete \
  --resource-group atomsResourceGroup \
  --name testcluster \
  --yes --no-wait

//delete everything inside the resource group as well -EOD
az group delete \
  --name myAKSResourceGroup \
  --yes --no-wait

// delete everything argocd related.
kubectl delete applications.argoproj.io --all -n argocd --ignore-not-found

kubectl delete namespace argocd --ignore-not-found

kubectl delete crd \
  applications.argoproj.io \
  applicationsets.argoproj.io \
  appprojects.argoproj.io \
  argocdextensions.argoproj.io \
  --ignore-not-found

kubectl delete clusterrolebinding \
  argocd-application-controller \
  argocd-server \
  argocd-dex-server \
  argocd-notifications-controller \
  argocd-applicationset-controller \
  --ignore-not-found

kubectl delete clusterrole \
  argocd-application-controller \
  argocd-server \
  argocd-dex-server \
  argocd-notifications-controller \
  argocd-applicationset-controller \
  --ignore-not-found

kubectl delete validatingwebhookconfiguration argocd-application-controller --ignore-not-found
kubectl delete mutatingwebhookconfiguration argocd-notifications-controller --ignore-not-found

kubectl get namespace argocd -o json \
  | jq '.spec.finalizers=[]' \
  | kubectl replace --raw "/api/v1/namespaces/argocd/finalize" -f -

