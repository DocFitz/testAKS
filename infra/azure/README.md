# testing bicep
ideally this works as follows...
you enter the command below,
you get the bicep output for veleroManagedIdentityClientId for each env and plug it into the correspoinding /apps/velero/values/<env>.yaml

# note that you must add the environment here
az deployment sub create \
  --location centralus \
  --template-file infra/azure/main.bicep \
  --parameters env=prod enablePrivateEndpoint=false

# the above...
creates rg, cnets, oidc and workload identity enabled, creates the storage account and container in rg backup-<env>, creates velero user-assigned MI + federated credential + rbac to the storage account. 


## private endpoints
deploy with enablePrivateEndpoint=true
storage account networks acls go to deny in the bicep above
cluster must be able to resolve the *.blob.core.windows.net private link via private dns zone link
