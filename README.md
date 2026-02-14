# explanation of repo
/clusters/env/apps/*.yaml are the child applications, i.e. specific values we want for that environment. 
/apps has all of the source manifest information.
root-app.yaml in the dev cluster points to clusters/dev/apps



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

