//cluster bootstrapping
az aks create \
  --resource-group atomsResourceGroup \
  --name testCluster \
  --location westus2 \
  --node-count 1 \
  --node-vm-size Standard_B2s_v2 \
  --enable-managed-identity \
  --generate-ssh-keys \
  --tier free \
 
//delete cluster if needed
az aks delete \
  --resource-group atomsResourceGroup \
  --name testCluster \
  --yes --no-wait

//delete everything inside the resource group as well -EOD
az group delete \
  --name myAKSResourceGroup \
  --yes --no-wait

//install argocd
kubectl apply --server-side \
  -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl apply -f app-of-apps.yaml

//get initial admin secret to change
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

//forward ui to local
kubectl port-forward svc/argocd-server -n argocd 8080:443

//validate managed cilium is installed
kubectl -n kube-system get pods -l k8s-app=cilium
kubectl -n kube-system get ds cilium

//cilium gateway api crds still need to be installed seperately.
