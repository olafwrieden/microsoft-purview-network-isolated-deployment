param deploymentDatetime string
param resourceLocation string
param ctrlDeployPurview bool
param deploymentScriptUAMIId string
param purviewScriptArguments string
param purviewPSScriptLocation string
param cleanUpScriptArguments string
param cleanUpPSScriptLocation string

resource r_purviewPostDeployScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = if (ctrlDeployPurview == true) {
  name: 'PurviewPostDeploymentScript-${deploymentDatetime}'
  location: resourceLocation
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentScriptUAMIId}': {}
    }
  }
  properties: {
    azPowerShellVersion: '7.2.4'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    timeout: 'PT30M'
    arguments: purviewScriptArguments
    primaryScriptUri: base64ToString(purviewPSScriptLocation)
  }
}

resource r_cleanUpPostDeployScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'CleanUpPostDeploymentScript-${deploymentDatetime}'
  dependsOn: [
    r_purviewPostDeployScript
  ]
  location: resourceLocation
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentScriptUAMIId}': {}
    }
  }
  properties: {
    azPowerShellVersion: '7.2.4'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    timeout: 'PT30M'
    arguments: cleanUpScriptArguments
    primaryScriptUri: base64ToString(cleanUpPSScriptLocation)
  }
}
