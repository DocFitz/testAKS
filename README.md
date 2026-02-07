//install argocd
kubectl apply --server-side \
  -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

//apply the app-of-apps
kubectl apply -f app-of-apps.yaml

//get initial admin secret to change
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

//forward ui to local
kubectl port-forward svc/argocd-server -n argocd 8080:443

