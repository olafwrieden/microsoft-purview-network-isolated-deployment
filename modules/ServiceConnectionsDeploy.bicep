param ctrlDeployPurview bool
param purviewIdentityPrincipalID string
param keyVaultName string

//Key Vault Access Policy for Purview
module m_KeyVaultPurviewAccessPolicy 'KeyVaultPurviewAccessPolicy.bicep' = if (ctrlDeployPurview == true) {
  name: 'KeyVaultPurviewAccessPolicy'
  params: {
    keyVaultName: keyVaultName
    purviewIdentityPrincipalID: purviewIdentityPrincipalID
  }
}
