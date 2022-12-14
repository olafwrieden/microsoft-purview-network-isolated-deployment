param vNetID string
param vNetName string
param subnetID string

param resourceLocation string

param ctrlDeployPrivateDNSZones bool
param ctrlDeployPurview bool

//Key Vault Params
param keyVaultID string
param keyVaultName string

//Purview Params
param purviewAccountID string
param purviewAccountName string
param purviewManagedStorageAccountID string
param purviewManagedEventHubNamespaceID string

var storageEnvironmentDNS = environment().suffixes.storage

//Deploy Private DNS Zones required to suppport Private Endpoints
module m_DeployPrivateDNSZones './PrivateDNSZonesDeploy.bicep' = if (ctrlDeployPrivateDNSZones == true) {
  name: 'DeployPrivateDNSZones'
  params: {
    vNetID: vNetID
    vNetName: vNetName
    ctrlDeployPurview: ctrlDeployPurview
  }
}

//==================================================================================================================

//Private DNS Zone References
resource r_privateDNSZoneKeyVault 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.vaultcore.azure.net'
}

resource r_privateDNSZoneBlob 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.blob.${storageEnvironmentDNS}'
}

resource r_privateDNSZoneStorageQueue 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.queue.${storageEnvironmentDNS}'
}

resource r_privateDNSZoneServiceBus 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.servicebus.windows.net'
}

resource r_privateDNSZonePurviewAccount 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.purview.azure.com'
}

resource r_privateDNSZonePurviewPortal 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.purviewstudio.azure.com'
}

//Key Vault Private Endpoint
module m_keyVaultPrivateLink './PrivateEndpoint.bicep' = {
  name: 'KeyVaultPrivateLink'
  dependsOn: [
    m_DeployPrivateDNSZones
  ]
  params: {
    groupID: 'vault'
    privateEndpoitName: keyVaultName
    privateLinkServiceId: keyVaultID
    resourceLocation: resourceLocation
    subnetID: subnetID
    deployDNSZoneGroup: ctrlDeployPrivateDNSZones
    privateDNSZoneConfigs: [
      {
        name: 'privatelink-vaultcore-azure-net'
        properties: {
          privateDnsZoneId: r_privateDNSZoneKeyVault.id
        }
      }
    ]
  }
}

module m_purviewBlobPrivateLink 'PrivateEndpoint.bicep' = if (ctrlDeployPurview == true) {
  name: 'PurviewBlobPrivateLink'
  dependsOn: [
    m_DeployPrivateDNSZones
  ]
  params: {
    groupID: 'blob'
    privateEndpoitName: '${purviewAccountName}-blob'
    privateLinkServiceId: purviewManagedStorageAccountID
    resourceLocation: resourceLocation
    subnetID: subnetID
    deployDNSZoneGroup: ctrlDeployPrivateDNSZones
    privateDNSZoneConfigs: [
      {
        name: 'privatelink-blob-core-windows-net'
        properties: {
          privateDnsZoneId: r_privateDNSZoneBlob.id
        }
      }
    ]
  }
}

module m_purviewQueuePrivateLink 'PrivateEndpoint.bicep' = if (ctrlDeployPurview == true) {
  name: 'PurviewQueuePrivateLink'
  dependsOn: [
    m_DeployPrivateDNSZones
  ]
  params: {
    groupID: 'queue'
    privateEndpoitName: '${purviewAccountName}-queue'
    privateLinkServiceId: purviewManagedStorageAccountID
    resourceLocation: resourceLocation
    subnetID: subnetID
    deployDNSZoneGroup: ctrlDeployPrivateDNSZones
    privateDNSZoneConfigs: [
      {
        name: 'privatelink-queue-core-windows-net'
        properties: {
          privateDnsZoneId: r_privateDNSZoneStorageQueue.id
        }
      }
    ]
  }
}

module m_purviewEventHubPrivateLink 'PrivateEndpoint.bicep' = if (ctrlDeployPurview == true) {
  name: 'PurviewEventHubPrivateLink'
  dependsOn: [
    m_DeployPrivateDNSZones
  ]
  params: {
    groupID: 'namespace'
    privateEndpoitName: '${purviewAccountName}-namespace'
    privateLinkServiceId: purviewManagedEventHubNamespaceID
    resourceLocation: resourceLocation
    subnetID: subnetID
    deployDNSZoneGroup: ctrlDeployPrivateDNSZones
    privateDNSZoneConfigs: [
      {
        name: 'privatelink-servicebus-windows-net'
        properties: {
          privateDnsZoneId: r_privateDNSZoneServiceBus.id
        }
      }
    ]
  }
}

module m_purviewAccountPrivateLink 'PrivateEndpoint.bicep' = if (ctrlDeployPurview == true) {
  name: 'PurviewAccountPrivateLink'
  dependsOn: [
    m_DeployPrivateDNSZones
  ]
  params: {
    groupID: 'account'
    privateEndpoitName: '${purviewAccountName}-account'
    privateLinkServiceId: purviewAccountID
    resourceLocation: resourceLocation
    subnetID: subnetID
    deployDNSZoneGroup: ctrlDeployPrivateDNSZones
    privateDNSZoneConfigs: [
      {
        name: 'privatelink-purview-azure-com-account'
        properties: {
          privateDnsZoneId: r_privateDNSZonePurviewAccount.id
        }
      }
    ]
  }
}

module m_purviewPortalPrivateLink 'PrivateEndpoint.bicep' = if (ctrlDeployPurview == true) {
  name: 'PurviewPortalPrivateLink'
  dependsOn: [
    m_DeployPrivateDNSZones
  ]
  params: {
    groupID: 'portal'
    privateEndpoitName: '${purviewAccountName}-portal'
    privateLinkServiceId: purviewAccountID
    resourceLocation: resourceLocation
    subnetID: subnetID
    deployDNSZoneGroup: ctrlDeployPrivateDNSZones
    privateDNSZoneConfigs: [
      {
        name: 'privatelink-purview-azure-com-portal'
        properties: {
          privateDnsZoneId: r_privateDNSZonePurviewPortal.id
        }
      }
    ]
  }
}
