param(
  [string] $PurviewAccountID,
  [string] $PurviewAccountName,
  [string] $SubscriptionId,
  [string] $ResourceGroupName,
  [string] $ScanEndpoint,
  [string] $APIVersion,
  [string] $KeyVaultName,
  [string] $KeyVaultID,
  [string] $UAMIIdentityID,
  [string] $NetworkIsolationMode
)

#------------------------------------------------------------------------------------------------------------
# FUNCTION DEFINITIONS
#------------------------------------------------------------------------------------------------------------

function Set-PurviewControlPlaneOperation{
  param (
    [string] $PurviewAccountID,
    [string] $HttpRequestBody
  )
  
  $uri = "https://management.azure.com$PurviewAccountID`?api-version=2021-07-01"
  $token = (Get-AzAccessToken -Resource "https://management.azure.com").Token
  $headers = @{ Authorization = "Bearer $token" }

  $retrycount = 1
  $completed = $false
  $secondsDelay = 30

  while (-not $completed) {
    try {
      Invoke-RestMethod -Method Patch -ContentType "application/json" -Uri $uri -Headers $headers -Body $HttpRequestBody -ErrorAction Stop
      Write-Host "Control plane operation completed successfully."
      $completed = $true
    }
    catch {
      if ($retrycount -ge $retries) {
          Write-Host "Control plane operation failed the maximum number of $retryCount times."
          Write-Warning $Error[0]
          throw
      } else {
          Write-Host "Control plane operation failed $retryCount time(s). Retrying in $secondsDelay seconds."
          Write-Warning $Error[0]
          Start-Sleep $secondsDelay
          $retrycount++
      }
    }
  }
}


$retries = 10
$secondsDelay = 10

#------------------------------------------------------------------------------------------------------------
# ADD UAMIIdentityID TO COLLECTION ADMINISTRATOR ROLE
#------------------------------------------------------------------------------------------------------------

#Call Control Plane API to add UAMI as Collection Administrator

$token = (Get-AzAccessToken -Resource "https://management.azure.com").Token
$headers = @{ Authorization = "Bearer $token" }

$uri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Purview/accounts/$PurviewAccountName/addRootCollectionAdmin?api-version=2021-07-01"

$body = "{
  objectId: ""$UAMIIdentityID""
}"

$retrycount = 1
$completed = $false

while (-not $completed) {
  try {
    Invoke-RestMethod -Method Post -ContentType "application/json" -Uri $uri -Headers $headers -Body $body -ErrorAction Stop
    $completed = $true
  }
  catch {
    if ($retrycount -ge $retries) {
        Write-Host "Metadata policy update failed the maximum number of $retryCount times."
        throw
    } else {
        Write-Host "Metadata policy update failed $retryCount time(s). Retrying in $secondsDelay seconds."
        Write-Warning $Error[0]
        Start-Sleep $secondsDelay
        $retrycount++
    }
  }
}

#------------------------------------------------------------------------------------------------------------
# CREATE KEY VAULT CONNECTION
#------------------------------------------------------------------------------------------------------------

$token = (Get-AzAccessToken -Resource "https://purview.azure.net").Token
$headers = @{ Authorization = "Bearer $token" }


$uri = $ScanEndpoint + "/azureKeyVaults/$KeyVaultName`?api-version=2018-12-01-preview" 
#Create KeyVault Connection
$body = "{
  ""name"": ""$KeyVaultName"",
  ""id"": ""$KeyVaultID"",
  ""properties"": {
      ""baseUrl"": ""https://$KeyVaultName.vault.azure.net/""
  }
}"

Write-Host "Creating Azure KeyVault connection..."

$retrycount = 1
$completed = $false

while (-not $completed) {
  try {
    Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $body -ErrorAction Stop
    Write-Host "KeyVault connection created successfully."
    $completed = $true
  }
  catch {
    if ($retrycount -ge $retries) {
        Write-Host "KeyVault connection failed the maximum number of $retryCount times."
        throw
    } else {
        Write-Host "KeyVault connection failed $retryCount time(s). Retrying in $secondsDelay seconds."
        Write-Warning $Error[0]
        Start-Sleep $secondsDelay
        $retrycount++
    }
  }
}

Write-Host "Registering Azure Data Lake data source..."

#------------------------------------------------------------------------------------------------------------
# CONTROL PLANE OPERATOR: DISABLE PUBLIC NETWORK ACCESS
# For vNet-integrated deployments, disable public network access. Access to Synapse only through private endpoints.
#------------------------------------------------------------------------------------------------------------

if ($NetworkIsolationMode -eq "vNet") {
  $body = "{properties:{publicNetworkAccess:""Disabled""}}"
  Set-PurviewControlPlaneOperation -PurviewAccountID $PurviewAccountID -HttpRequestBody $body
}

