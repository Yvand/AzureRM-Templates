Publish-AzureRmVMDscConfiguration -ConfigurationPath "..\DSCConfiguration\ConfigureSharePointAppServer.ps1" -OutputArchivePath "..\DSC\ConfigureSharePointAppServer.ps1.zip" -Force

Publish-AzureRmVMDscConfiguration -ConfigurationPath "..\DSCConfiguration\ConfigureSharePointDCacheServer.ps1" -OutputArchivePath "..\DSC\ConfigureSharePointDCacheServer.ps1.zip" -Force

Publish-AzureRmVMDscConfiguration -ConfigurationPath "..\DSCConfiguration\ConfigureSharePointSCServer.ps1" -OutputArchivePath "..\DSC\ConfigureSharePointSCServer.ps1.zip" -Force

Publish-AzureRmVMDscConfiguration -ConfigurationPath "..\DSCConfiguration\ConfigureSharePointSIServer.ps1" -OutputArchivePath "..\DSC\ConfigureSharePointSIServer.ps1.zip" -Force

Publish-AzureRmVMDscConfiguration -ConfigurationPath "..\DSCConfiguration\ConfigureSharePointWFEServer.ps1" -OutputArchivePath "..\DSC\ConfigureSharePointWFEServer.ps1.zip" -Force

Publish-AzureRmVMDscConfiguration -ConfigurationPath "..\DSCConfiguration\ConfigureSQLReplica.ps1" -OutputArchivePath "..\DSC\ConfigureSQLReplica.ps1.zip" -Force

Publish-AzureRmVMDscConfiguration -ConfigurationPath "..\DSCConfiguration\PrepareSQLWitnessVM.ps1" -OutputArchivePath "..\DSC\PrepareSQLWitnessVM.ps1.zip" -Force

Publish-AzureRmVMDscConfiguration -ConfigurationPath "..\DSCConfiguration\ConfigureSQLAOCluster.ps1" -OutputArchivePath "..\DSC\ConfigureSQLAOCluster.ps1.zip" -Force