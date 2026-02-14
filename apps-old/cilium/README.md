# cilium status page
cilium status

# hubble port forwarding
kubectl port-forward -n kube-system svc/hubble-ui 12000:80

http://localhost:12000

# validate hubble services 
kubectl get svc -n kube-system | grep hubble
