$ResourceGroupName = "crgar-aks-prv4-spoke-rg"

az deployment group create `
  --name aksdeployment1 `
  --resource-group $ResourceGroupName `
  --template-file main.bicep `
  --parameters '@parameters.json' `
  --mode Incremental