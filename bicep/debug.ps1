$ResourceGroupName = "crgar-aks-prv4-spoke-rg"

New-AzResourceGroupDeployment `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile .\main.bicep `
    -TemplateParameterFile .\parameters.json `
    -Mode Incremental


$params = get-content .\parameters.json

az deployment group create `
  --name aksdeployment1 `
  --resource-group $ResourceGroupName `
  --template-file main.bicep `
  --parameters $params `
  --mode Incremental