# microsoft-purview-network-isolated-deployment
A bicep script to automate the deployment of Microsoft Purview with vNets and Private Endpoints.

1. `az login`
2. `az account set --subscription [your-subscription-id]`
3. `az deployment group create --resource-group [name-of-your-rg] --template-file .\MicrosoftPurviewDeploy.bicep --parameters .\parameters.json`
