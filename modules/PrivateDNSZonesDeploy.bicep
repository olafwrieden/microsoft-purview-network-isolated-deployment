param vNetID string
param vNetName string

param ctrlDeployPurview bool

var environmentStorageDNS = environment().suffixes.storage

//Private DNS Zones required for Storage DFS Private Link: privatelink.dfs.core.windows.net
//Required for Azure Data Lake Gen2
module m_privateDNSZoneStorageDFS './PrivateDNSZone.bicep' = {
  name: 'PrivateDNSZoneStorageDFS'
  params: {
    dnsZoneName: 'privatelink.dfs.${environmentStorageDNS}'
    vNetID: vNetID
    vNetName: vNetName
  }
}

//Private DNS Zones required for Storage Blob Private Link: privatelink.blob.core.windows.net
//Required for Purview, Azure ML
module m_privateDNSZoneStorageBlob 'PrivateDNSZone.bicep' = if (ctrlDeployPurview == true) {
  name: 'PrivateDNSZoneStorageBlob'
  params: {
    dnsZoneName: 'privatelink.blob.${environmentStorageDNS}'
    vNetID: vNetID
    vNetName: vNetName
  }
}

//Private DNS Zones required for Storage Queue Private Link: privatelink.queue.core.windows.net
//Required for Purview
module m_privateDNSZoneStorageQueue 'PrivateDNSZone.bicep' = if (ctrlDeployPurview == true) {
  name: 'PrivateDNSZoneStorageQueue'
  params: {
    dnsZoneName: 'privatelink.queue.${environmentStorageDNS}'
    vNetID: vNetID
    vNetName: vNetName
  }
}

//Private DNS Zones required for Synapse Private Link: privatelink.vaultcore.azure.net
//Required for KeyVault
module m_privateDNSZoneKeyVault './PrivateDNSZone.bicep' = {
  name: 'PrivateDNSZoneKeyVault'
  params: {
    dnsZoneName: 'privatelink.vaultcore.azure.net'
    vNetID: vNetID
    vNetName: vNetName
  }
}

//Private DNS Zones required for EventHubs: privatelink.servicebus.windows.net
//Required for Purview Event Hubs
module m_privateDNSZoneServiceBus './PrivateDNSZone.bicep' = if (ctrlDeployPurview == true) {
  name: 'PrivateDNSZonePurviewServiceBus'
  params: {
    dnsZoneName: 'privatelink.servicebus.windows.net'
    vNetID: vNetID
    vNetName: vNetName
  }
}

//Purview Account private endpoint
module m_privateDNSZonePurviewAccount 'PrivateDNSZone.bicep' = if (ctrlDeployPurview == true) {
  name: 'PrivateDNSZonePurviewAccount'
  params: {
    dnsZoneName: 'privatelink.purview.azure.com'
    vNetID: vNetID
    vNetName: vNetName
  }
}

//Purview Portal private endpoint
module m_privateDNSZonePurviewPortal 'PrivateDNSZone.bicep' = if (ctrlDeployPurview == true) {
  name: 'PrivateDNSZonePurviewPortal'
  params: {
    dnsZoneName: 'privatelink.purviewstudio.azure.com'
    vNetID: vNetID
    vNetName: vNetName
  }
}

output storageDFSPrivateDNSZoneID string = m_privateDNSZoneStorageDFS.outputs.dnsZoneID
output storageBlobPrivateDNSZoneID string = ctrlDeployPurview == true ? m_privateDNSZoneStorageBlob.outputs.dnsZoneID : ''
output storageQueuePrivateDNSZoneID string = ctrlDeployPurview ? m_privateDNSZoneStorageQueue.outputs.dnsZoneID : ''
output keyVaultPrivateDNSZoneID string = m_privateDNSZoneKeyVault.outputs.dnsZoneID
output serviceBusPrivateDNSZoneID string = ctrlDeployPurview == true ? m_privateDNSZoneServiceBus.outputs.dnsZoneID : ''
output purviewAccountPrivateDNSZoneID string = ctrlDeployPurview ? m_privateDNSZonePurviewAccount.outputs.dnsZoneID : ''
