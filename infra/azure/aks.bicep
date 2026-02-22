// filepath: infra/azure/aks.bicep
param location string
param aksName string
param subnetId string

param dnsServiceIp string = '10.0.0.10'
param serviceCidr string = '10.0.0.0/16'
param podCidr string = '192.168.0.0/16'

param nodeVmSize string
param nodeCount int

resource aks 'Microsoft.ContainerService/managedClusters@2025-05-01' = {
  name: aksName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: aksName

    oidcIssuerProfile: {
      enabled: true
    }

    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }

    agentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        count: nodeCount
        vmSize: nodeVmSize
        osType: 'Linux'
        type: 'VirtualMachineScaleSets'
        vnetSubnetId: subnetId
      }
    ]

    networkProfile: {
      networkPlugin: 'none'
      networkPolicy: 'none'
      serviceCidr: serviceCidr
      dnsServiceIP: dnsServiceIp
      podCidr: podCidr
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
    }
  }
}

output oidcIssuerUrl string = aks.properties.oidcIssuerProfile.issuerUrl
