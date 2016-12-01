Set-PSRepository -Name PSGallery -SourceLocation https://www.powershellgallery.com/api/v2/ -InstallationPolicy Trusted

Install-Module -Name SharePointDsc -Confirm:$false -Force
Install-Module  -Name xWebAdministration -Confirm:$false -Force
Install-Module  -Name xCredSSP -Confirm:$false -RequiredVersion 1.0.1 -Force
Install-Module  -Name xSmbShare -Confirm:$false 
Install-Module  -Name xDisk -Confirm:$false 
Install-Module  -Name xNetworking -Confirm:$false 
Install-Module  -Name xStorage -Confirm:$false 
Install-Module  -Name xActiveDirectory  -Confirm:$false 
Install-Module  -Name xDnsServer  -Confirm:$false 
Install-Module  -Name xSqlServer -Confirm:$false 
Install-Module  -Name xSqlPs -Confirm:$false 
Install-Module  -Name xDscDiagnostics -Confirm:$false 
Install-Module -Name xComputerManagement -Confirm:$false
