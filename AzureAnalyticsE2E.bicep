//********************************************************
// Global Parameters
//********************************************************

@allowed([
  'default'
  'vNet'
])
@description('Network Isolation Mode')
param networkIsolationMode string = 'default'

@description('Resource Location')
param resourceLocation string = resourceGroup().location

@description('Unique Suffix')
param uniqueSuffix string = substring(uniqueString(resourceGroup().id), 0, 6)

//********************************************************
// Workload Deployment Control Parameters
//********************************************************

param ctrlDeployPurview bool = true //Controls the deployment of Azure Purview
param ctrlDeployPrivateDNSZones bool = true //Controls the creation of private DNS zones for private links

@allowed([
  'new'
  'existing'
])
param ctrlNewOrExistingVNet string = 'new'

param deploymentDatetime string = utcNow()
//********************************************************
// Resource Config Parameters
//********************************************************

//vNet Parameters

param existingVNetResourceGroupName string = resourceGroup().name

@description('Virtual Network Name')
param vNetName string = 'azvnet${uniqueSuffix}'

@description('Virtual Network IP Address Space')
param vNetIPAddressPrefixes array = [
  '10.1.0.0/16'
]

@description('Virtual Network Subnet Name')
param vNetSubnetName string = 'default'

@description('Virtual Network Subnet Name')
param vNetSubnetIPAddressPrefix string = '10.1.0.0/24'
//----------------------------------------------------------------------

//Purview Account Parameters
@description('Purview Account Name')
param purviewAccountName string = 'azpurview${uniqueSuffix}'

@description('Purview Managed Resource Group Name')
param purviewManagedRGName string = '${purviewAccountName}-mrg'

//----------------------------------------------------------------------

//Key Vault Parameters
@description('Data Lake Storage Account Name')
param keyVaultName string = 'azkeyvault${uniqueSuffix}'
//----------------------------------------------------------------------

//********************************************************
// Variables
//********************************************************

var deploymentScriptUAMIName = toLower('${resourceGroup().name}-uami')

//********************************************************
// Platform Services 
//********************************************************

//Deploy required platform services
module m_PlatformServicesDeploy 'modules/PlatformServicesDeploy.bicep' = {
  name: 'PlatformServicesDeploy'
  params: {
    networkIsolationMode: networkIsolationMode
    deploymentScriptUAMIName: deploymentScriptUAMIName
    keyVaultName: keyVaultName
    resourceLocation: resourceLocation
    ctrlNewOrExistingVNet: ctrlNewOrExistingVNet
    existingVNetResourceGroupName: existingVNetResourceGroupName
    vNetIPAddressPrefixes: vNetIPAddressPrefixes
    vNetSubnetIPAddressPrefix: vNetSubnetIPAddressPrefix
    vNetSubnetName: vNetSubnetName
    vNetName: vNetName
  }
}

//********************************************************
// PURVIEW DEPLOY
//********************************************************

//Deploy Purview Account
module m_PurviewDeploy 'modules/PurviewDeploy.bicep' = if (ctrlDeployPurview == true) {
  name: 'PurviewDeploy'
  params: {
    purviewAccountName: purviewAccountName
    purviewManagedRGName: purviewManagedRGName
    resourceLocation: resourceLocation
  }
}

//********************************************************
// SERVICE CONNECTIONS DEPLOY
//********************************************************

module m_ServiceConnectionsDeploy 'modules/ServiceConnectionsDeploy.bicep' = {
  name: 'ServiceConnectionsDeploy'
  dependsOn: [
    m_PlatformServicesDeploy
    m_PurviewDeploy
  ]
  params: {
    ctrlDeployPurview: ctrlDeployPurview
    keyVaultName: m_PlatformServicesDeploy.outputs.keyVaultName
    purviewIdentityPrincipalID: ctrlDeployPurview ? m_PurviewDeploy.outputs.purviewIdentityPrincipalID : ''
  }
}

//********************************************************
// RBAC Role Assignments
//********************************************************

module m_RBACRoleAssignment 'modules/AzureRBACDeploy.bicep' = {
  name: 'RBACRoleAssignmentDeploy'
  dependsOn: [
    m_ServiceConnectionsDeploy
  ]
  params: {
    ctrlDeployPurview: ctrlDeployPurview
    purviewIdentityPrincipalID: ctrlDeployPurview ? m_PurviewDeploy.outputs.purviewIdentityPrincipalID : ''
    UAMIPrincipalID: m_PlatformServicesDeploy.outputs.deploymentScriptUAMIPrincipalID
    // purviewAccountName: purviewAccountName
  }
}

module m_VirtualNetworkIntegration 'modules/VirtualNetworkIntegrationDeploy.bicep' = if (networkIsolationMode == 'vNet') {
  name: 'VirtualNetworkIntegration'
  dependsOn: [
    m_PlatformServicesDeploy
    m_PurviewDeploy
  ]
  params: {
    ctrlDeployPrivateDNSZones: ctrlDeployPrivateDNSZones
    ctrlDeployPurview: ctrlDeployPurview
    vNetName: vNetName
    subnetID: m_PlatformServicesDeploy.outputs.subnetID
    vNetID: m_PlatformServicesDeploy.outputs.vNetID
    keyVaultID: m_PlatformServicesDeploy.outputs.keyVaultID
    keyVaultName: m_PlatformServicesDeploy.outputs.keyVaultName
    purviewAccountID: ctrlDeployPurview ? m_PurviewDeploy.outputs.purviewAccountID : ''
    purviewAccountName: ctrlDeployPurview ? m_PurviewDeploy.outputs.purviewAccountName : ''
    purviewManagedEventHubNamespaceID: ctrlDeployPurview ? m_PurviewDeploy.outputs.purviewManagedEventHubNamespaceID : ''
    purviewManagedStorageAccountID: ctrlDeployPurview ? m_PurviewDeploy.outputs.purviewManagedStorageAccountID : ''
    resourceLocation: resourceLocation
  }
}

//********************************************************
// Post Deployment Scripts
//********************************************************

resource r_deploymentScriptUAMI 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: deploymentScriptUAMIName
}

//Purview Deployment Script: script location encoded in Base64
var purviewPSScriptLocation = 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0F6dXJlL2F6dXJlLXN5bmFwc2UtYW5hbHl0aWNzLWVuZDJlbmQvbWFpbi9EZXBsb3kvc2NyaXB0cy9QdXJ2aWV3UG9zdERlcGxveS5wczE='
var purviewScriptArguments = '-PurviewAccountID ${ctrlDeployPurview ? m_PurviewDeploy.outputs.purviewAccountID : ''} -PurviewAccountName ${purviewAccountName} -SubscriptionID ${subscription().subscriptionId} -ResourceGroupName ${resourceGroup().name} -UAMIIdentityID ${m_PlatformServicesDeploy.outputs.deploymentScriptUAMIPrincipalID} -ScanEndpoint ${ctrlDeployPurview ? m_PurviewDeploy.outputs.purviewScanEndpoint : ''} -APIVersion ${ctrlDeployPurview ? m_PurviewDeploy.outputs.purviewAPIVersion : ''}  -KeyVaultName ${keyVaultName} -KeyVaultID ${m_PlatformServicesDeploy.outputs.keyVaultID} -NetworkIsolationMode ${networkIsolationMode}'

//CleanUp Deployment Script: script location encoded in Base64
var cleanUpPSScriptLocation = 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL29sYWZ3cmllZGVuL21pY3Jvc29mdC1wdXJ2aWV3LW5ldHdvcmstaXNvbGF0ZWQtZGVwbG95bWVudC9tYXN0ZXIvc2NyaXB0cy9DbGVhblVwUG9zdERlcGxveS5wczE='
var cleanUpScriptArguments = '-UAMIResourceID ${r_deploymentScriptUAMI.id}'

module m_PostDeploymentScripts 'modules/PostDeploymentScripts.bicep' = {
  name: 'PostDeploymentScript'
  dependsOn: [
    m_RBACRoleAssignment
    m_VirtualNetworkIntegration
  ]
  params: {
    cleanUpPSScriptLocation: cleanUpPSScriptLocation
    cleanUpScriptArguments: cleanUpScriptArguments
    ctrlDeployPurview: ctrlDeployPurview
    deploymentDatetime: deploymentDatetime
    deploymentScriptUAMIId: m_PlatformServicesDeploy.outputs.deploymentScriptUAMIID
    purviewPSScriptLocation: purviewPSScriptLocation
    purviewScriptArguments: purviewScriptArguments
    resourceLocation: resourceLocation
  }
}
