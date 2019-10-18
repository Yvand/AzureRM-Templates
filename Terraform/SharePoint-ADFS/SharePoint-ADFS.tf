# Configure the Azure Provider
provider "azurerm" {
}

# Create a resource group
resource "azurerm_resource_group" "resourceGroup" {
  name     = var.resourceGroupName
  location = var.location
}

# Create network security groups
resource "azurerm_network_security_group" "NSG-VNet-DC" {
  name                = "NSG-VNet-${var.vmDC["vmName"]}"
  location            = azurerm_resource_group.resourceGroup.location
  resource_group_name = azurerm_resource_group.resourceGroup.name

  security_rule {
    name                       = "allow-rdp-rule"
    description                = "Allow RDP"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
    access                     = "Allow"
    priority                   = 100
    direction                  = "Inbound"
  }
}

resource "azurerm_network_security_group" "NSG-VNet-SQL" {
  name                = "NSG-VNet-${var.vmSQL["vmName"]}"
  location            = azurerm_resource_group.resourceGroup.location
  resource_group_name = azurerm_resource_group.resourceGroup.name

  security_rule {
    name                       = "allow-rdp-rule"
    description                = "Allow RDP"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
    access                     = "Allow"
    priority                   = 100
    direction                  = "Inbound"
  }

  security_rule {
    name                       = "allow-sql-from-sp-vnet-rule"
    description                = "Allow FE Subnet"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = var.networkSettings["vNetPrivateSubnetSPPrefix"]
    destination_address_prefix = "*"
    access                     = "Allow"
    priority                   = 101
    direction                  = "Inbound"
  }
}

resource "azurerm_network_security_group" "NSG-VNet-SP" {
  name                = "NSG-VNet-${var.vmSP["vmName"]}"
  location            = azurerm_resource_group.resourceGroup.location
  resource_group_name = azurerm_resource_group.resourceGroup.name

  security_rule {
    name                       = "allow-rdp-rule"
    description                = "Allow RDP"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
    access                     = "Allow"
    priority                   = 100
    direction                  = "Inbound"
  }
}

# Create the virtual network, 3 subnets, and associate each subnet with its Network Security Group
resource "azurerm_virtual_network" "VNet" {
  name                = "${azurerm_resource_group.resourceGroup.name}-vnet"
  location            = azurerm_resource_group.resourceGroup.location
  resource_group_name = azurerm_resource_group.resourceGroup.name
  address_space = [var.networkSettings["vNetPrivatePrefix"]]
}

# Subnet and NSG for DC
resource "azurerm_subnet" "Subnet-DC" {
  name                 = "Subnet-${var.vmDC["vmName"]}"
  resource_group_name  = azurerm_resource_group.resourceGroup.name
  virtual_network_name = azurerm_virtual_network.VNet.name
  address_prefix       = var.networkSettings["vNetPrivateSubnetDCPrefix"]
  network_security_group_id = azurerm_network_security_group.NSG-VNet-DC.id
}

resource "azurerm_subnet_network_security_group_association" "NSG-Associate-DCSubnet" {
  subnet_id                 = azurerm_subnet.Subnet-DC.id
  network_security_group_id = azurerm_network_security_group.NSG-VNet-DC.id
}

# Subnet and NSG for SQL
# Delay subnet creation to workaround bug https://github.com/terraform-providers/terraform-provider-azurerm/issues/2758
resource "null_resource" "delay_subnet_sql" {
  provisioner "local-exec" {
    command = "ping 127.0.0.1 -n 6 > nul"
  }

  triggers = {
    "before" = "${azurerm_subnet.Subnet-DC.id}"
  }
}

resource "azurerm_subnet" "Subnet-SQL" {
  name                 = "Subnet-${var.vmSQL["vmName"]}"
  resource_group_name  = azurerm_resource_group.resourceGroup.name
  virtual_network_name = azurerm_virtual_network.VNet.name
  address_prefix       = var.networkSettings["vNetPrivateSubnetSQLPrefix"]
  network_security_group_id = azurerm_network_security_group.NSG-VNet-SQL.id
  depends_on                = ["null_resource.delay_subnet_sql"]
}

resource "azurerm_subnet_network_security_group_association" "NSG-Associate-SQLSubnet" {
  subnet_id                 = azurerm_subnet.Subnet-SQL.id
  network_security_group_id = azurerm_network_security_group.NSG-VNet-SQL.id
}

# Subnet and NSG for SP
# Delay subnet creation to workaround bug https://github.com/terraform-providers/terraform-provider-azurerm/issues/2758
resource "null_resource" "delay_subnet_sp" {
  provisioner "local-exec" {
    command = "ping 127.0.0.1 -n 6 > nul"
  }

  triggers = {
    "before" = "${azurerm_subnet.Subnet-SQL.id}"
  }
}

resource "azurerm_subnet" "Subnet-SP" {
  name                 = "Subnet-${var.vmSP["vmName"]}"
  resource_group_name  = azurerm_resource_group.resourceGroup.name
  virtual_network_name = azurerm_virtual_network.VNet.name
  address_prefix       = var.networkSettings["vNetPrivateSubnetSPPrefix"]
  network_security_group_id = azurerm_network_security_group.NSG-VNet-SP.id
  depends_on                = ["null_resource.delay_subnet_sp"]
}

resource "azurerm_subnet_network_security_group_association" "NSG-Associate-SPSubnet" {
  subnet_id                 = azurerm_subnet.Subnet-SP.id
  network_security_group_id = azurerm_network_security_group.NSG-VNet-SP.id
}

# Create artifacts for VM DC
resource "azurerm_public_ip" "PublicIP-DC" {
  name                = "PublicIP-${var.vmDC["vmName"]}"
  location            = azurerm_resource_group.resourceGroup.location
  resource_group_name = azurerm_resource_group.resourceGroup.name
  domain_name_label   = "${lower(var.dnsLabelPrefix)}-${lower(var.vmDC["vmName"])}"
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "NIC-DC-0" {
  name                = "NIC-${var.vmDC["vmName"]}-0"
  location            = azurerm_resource_group.resourceGroup.location
  resource_group_name = azurerm_resource_group.resourceGroup.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.Subnet-DC.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.networkSettings["vmDCPrivateIPAddress"]
    public_ip_address_id          = azurerm_public_ip.PublicIP-DC.id
  }
}

# Create artifacts for VM SQL
resource "azurerm_public_ip" "PublicIP-SQL" {
  name                = "PublicIP-${var.vmSQL["vmName"]}"
  location            = azurerm_resource_group.resourceGroup.location
  resource_group_name = azurerm_resource_group.resourceGroup.name
  domain_name_label   = "${lower(var.dnsLabelPrefix)}-${lower(var.vmSQL["vmName"])}"
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "NIC-SQL-0" {
  name                = "NIC-${var.vmSQL["vmName"]}-0"
  location            = azurerm_resource_group.resourceGroup.location
  resource_group_name = azurerm_resource_group.resourceGroup.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.Subnet-SQL.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.PublicIP-SQL.id
  }
}

# Create artifacts for VM SP
resource "azurerm_public_ip" "PublicIP-SP" {
  name                = "PublicIP-${var.vmSP["vmName"]}"
  location            = azurerm_resource_group.resourceGroup.location
  resource_group_name = azurerm_resource_group.resourceGroup.name
  domain_name_label   = "${lower(var.dnsLabelPrefix)}-${lower(var.vmSP["vmName"])}"
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "NIC-SP-0" {
  name                = "NIC-${var.vmSP["vmName"]}-0"
  location            = azurerm_resource_group.resourceGroup.location
  resource_group_name = azurerm_resource_group.resourceGroup.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.Subnet-SP.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.PublicIP-SP.id
  }
}

# Create virtual machines
resource "azurerm_virtual_machine" "VM-DC" {
  name                  = "VM-${var.vmDC["vmName"]}"
  location              = azurerm_resource_group.resourceGroup.location
  resource_group_name   = azurerm_resource_group.resourceGroup.name
  network_interface_ids = [azurerm_network_interface.NIC-DC-0.id]
  vm_size               = var.vmDC["vmSize"]

  os_profile {
    computer_name  = var.vmDC["vmName"]
    admin_username = var.adminUserName
    admin_password = var.adminPassword
  }

  os_profile_windows_config {
    timezone                  = var.timeZone
    enable_automatic_upgrades = true
    provision_vm_agent        = true
  }

  storage_image_reference {
    publisher = var.vmDC["vmImagePublisher"]
    offer     = var.vmDC["vmImageOffer"]
    sku       = var.vmDC["vmImageSKU"]
    version   = "latest"
  }

  storage_os_disk {
    name              = "Disk-${var.vmDC["vmName"]}-OS"
    managed_disk_type = var.vmDC["storageAccountType"]
    create_option     = "FromImage"
    disk_size_gb      = "128"
    caching           = "ReadWrite"
    os_type           = "Windows"
  }
}

resource "azurerm_virtual_machine_extension" "VM-DC-DSC" {
  name                       = "VM-${var.vmDC["vmName"]}-DSC"
  location                   = azurerm_resource_group.resourceGroup.location
  resource_group_name        = azurerm_resource_group.resourceGroup.name
  virtual_machine_name       = azurerm_virtual_machine.VM-DC.name
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.9"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
  {
    "wmfVersion": "latest",
    "configuration": {
	    "url": "${var._artifactsLocation}${var.generalSettings["dscScriptsFolder"]}/${var.dscConfigureDCVM["fileName"]}${var._artifactsLocationSasToken}",
	    "function": "${var.dscConfigureDCVM["function"]}",
	    "script": "${var.dscConfigureDCVM["script"]}"
    },
    "configurationArguments": {
      "domainFQDN": "${var.domainFQDN}",
      "PrivateIP": "${var.networkSettings["vmDCPrivateIPAddress"]}"
    },
    "privacy": {
      "dataCollection": "enable"
    }
  }
  
SETTINGS


  protected_settings = <<PROTECTED_SETTINGS
  {
    "configurationArguments": {
      "AdminCreds": {
        "UserName": "${var.adminUserName}",
        "Password": "${var.adminPassword}"
      },
      "AdfsSvcCreds": {
        "UserName": "${var.generalSettings["adfsSvcUserName"]}",
        "Password": "${var.serviceAccountsPassword}"
      }
    }
  }
  
PROTECTED_SETTINGS

}

resource "azurerm_virtual_machine" "VM-SQL" {
  name                  = "VM-${var.vmSQL["vmName"]}"
  location              = azurerm_resource_group.resourceGroup.location
  resource_group_name   = azurerm_resource_group.resourceGroup.name
  network_interface_ids = [azurerm_network_interface.NIC-SQL-0.id]
  vm_size               = var.vmSQL["vmSize"]

  os_profile {
    computer_name  = var.vmSQL["vmName"]
    admin_username = var.adminUserName
    admin_password = var.adminPassword
  }

  os_profile_windows_config {
    timezone                  = var.timeZone
    enable_automatic_upgrades = true
    provision_vm_agent        = true
  }

  storage_image_reference {
    publisher = var.vmSQL["vmImagePublisher"]
    offer     = var.vmSQL["vmImageOffer"]
    sku       = var.vmSQL["vmImageSKU"]
    version   = "latest"
  }

  storage_os_disk {
    name              = "Disk-${var.vmSQL["vmName"]}-OS"
    managed_disk_type = var.vmSQL["storageAccountType"]
    create_option     = "FromImage"
    disk_size_gb      = "128"
    caching           = "ReadWrite"
    os_type           = "Windows"
  }
}

resource "azurerm_virtual_machine_extension" "VM-SQL-DSC" {
  name                       = "VM-${var.vmSQL["vmName"]}-DSC"
  location                   = azurerm_resource_group.resourceGroup.location
  resource_group_name        = azurerm_resource_group.resourceGroup.name
  virtual_machine_name       = azurerm_virtual_machine.VM-SQL.name
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.9"
  auto_upgrade_minor_version = true
  depends_on                 = [azurerm_virtual_machine_extension.VM-DC-DSC]

  settings = <<SETTINGS
  {
    "wmfVersion": "latest",
    "configuration": {
	    "url": "${var._artifactsLocation}${var.generalSettings["dscScriptsFolder"]}/${var.dscConfigureSQLVM["fileName"]}${var._artifactsLocationSasToken}",
	    "function": "${var.dscConfigureSQLVM["function"]}",
	    "script": "${var.dscConfigureSQLVM["script"]}"
    },
    "configurationArguments": {
      "DNSServer": "${var.networkSettings["vmDCPrivateIPAddress"]}",
      "DomainFQDN": "${var.domainFQDN}"
    },
    "privacy": {
      "dataCollection": "enable"
    }
  }
  
SETTINGS


  protected_settings = <<PROTECTED_SETTINGS
  {
    "configurationArguments": {
      "DomainAdminCreds": {
        "UserName": "${var.adminUserName}",
        "Password": "${var.adminPassword}"
      },
      "SqlSvcCreds": {
        "UserName": "${var.generalSettings["sqlSvcUserName"]}",
        "Password": "${var.serviceAccountsPassword}"
      },
      "SPSetupCreds": {
        "UserName": "${var.generalSettings["spSetupUserName"]}",
        "Password": "${var.serviceAccountsPassword}"
      }
    }
  }
  
PROTECTED_SETTINGS

}

resource "azurerm_virtual_machine" "VM-SP" {
  name                  = "VM-${var.vmSP["vmName"]}"
  location              = azurerm_resource_group.resourceGroup.location
  resource_group_name   = azurerm_resource_group.resourceGroup.name
  network_interface_ids = [azurerm_network_interface.NIC-SP-0.id]
  vm_size               = var.vmSP["vmSize"]

  os_profile {
    computer_name  = var.vmSP["vmName"]
    admin_username = var.adminUserName
    admin_password = var.adminPassword
  }

  os_profile_windows_config {
    timezone                  = var.timeZone
    enable_automatic_upgrades = true
    provision_vm_agent        = true
  }

  storage_image_reference {
    publisher = var.vmSP["vmImagePublisher"]
    offer     = var.vmSP["vmImageOffer"]
    sku       = var.vmSP["vmImageSKU"]
    version   = "latest"
  }

  storage_os_disk {
    name              = "Disk-${var.vmSP["vmName"]}-OS"
    managed_disk_type = var.vmSP["storageAccountType"]
    create_option     = "FromImage"
    disk_size_gb      = "128"
    caching           = "ReadWrite"
    os_type           = "Windows"
  }

  storage_data_disk {
    name              = "Disk-${var.vmSP["vmName"]}-Data"
    lun               = 0
    caching           = "ReadWrite"
    create_option     = "Empty"
    disk_size_gb      = 64
    managed_disk_type = var.vmSP["storageAccountType"]
  }
}

resource "azurerm_virtual_machine_extension" "VM-SP-DSC" {
  name                       = "VM-${var.vmSP["vmName"]}-DSC"
  location                   = azurerm_resource_group.resourceGroup.location
  resource_group_name        = azurerm_resource_group.resourceGroup.name
  virtual_machine_name       = azurerm_virtual_machine.VM-SP.name
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.9"
  auto_upgrade_minor_version = true
  depends_on                 = [azurerm_virtual_machine_extension.VM-DC-DSC]

  settings = <<SETTINGS
  {
    "wmfVersion": "latest",
    "configuration": {
	    "url": "${var._artifactsLocation}${var.generalSettings["dscScriptsFolder"]}/${var.dscConfigureSPVM["fileName"]}${var._artifactsLocationSasToken}",
	    "function": "${var.dscConfigureSPVM["function"]}",
	    "script": "${var.dscConfigureSPVM["script"]}"
    },
    "configurationArguments": {
      "DNSServer": "${var.networkSettings["vmDCPrivateIPAddress"]}",
      "DomainFQDN": "${var.domainFQDN}",
      "DCName": "${var.vmDC["vmName"]}",
      "SQLName": "${var.vmSQL["vmName"]}",
      "SQLAlias": "${var.generalSettings["sqlAlias"]}",
      "SharePointVersion": "${var.sharePointVersion}"
    },
    "privacy": {
      "dataCollection": "enable"
    }
  }
  
SETTINGS


  protected_settings = <<PROTECTED_SETTINGS
  {
    "configurationArguments": {
      "DomainAdminCreds": {
        "UserName": "${var.adminUserName}",
        "Password": "${var.adminPassword}"
      },
      "SPSetupCreds": {
        "UserName": "${var.generalSettings["spSetupUserName"]}",
        "Password": "${var.serviceAccountsPassword}"
      },
      "SPFarmCreds": {
        "UserName": "${var.generalSettings["spFarmUserName"]}",
        "Password": "${var.serviceAccountsPassword}"
      },
      "SPSvcCreds": {
        "UserName": "${var.generalSettings["spSvcUserName"]}",
        "Password": "${var.serviceAccountsPassword}"
      },
      "SPAppPoolCreds": {
        "UserName": "${var.generalSettings["spAppPoolUserName"]}",
        "Password": "${var.serviceAccountsPassword}"
      },
      "SPPassphraseCreds": {
        "UserName": "Passphrase",
        "Password": "${var.serviceAccountsPassword}"
      },
      "SPSuperUserCreds": {
        "UserName": "${var.generalSettings["spSuperUserName"]}",
        "Password": "${var.serviceAccountsPassword}"
      },
      "SPSuperReaderCreds": {
        "UserName": "${var.generalSettings["spSuperReaderName"]}",
        "Password": "${var.serviceAccountsPassword}"
      }
    }
  }
  
PROTECTED_SETTINGS

}

# Create artifacts for optional SharePoint FrontEnd if var.addFrontEndToFarm is true
resource "azurerm_public_ip" "PublicIP-FE" {
  count               = var.addFrontEndToFarm ? 1 : 0
  name                = "PublicIP-${var.vmFE["vmName"]}"
  location            = azurerm_resource_group.resourceGroup.location
  resource_group_name = azurerm_resource_group.resourceGroup.name
  domain_name_label   = "${lower(var.dnsLabelPrefix)}-${lower(var.vmFE["vmName"])}"
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "NIC-FE-0" {
  count               = var.addFrontEndToFarm ? 1 : 0
  name                = "NIC-${var.vmFE["vmName"]}-0"
  location            = azurerm_resource_group.resourceGroup.location
  resource_group_name = azurerm_resource_group.resourceGroup.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.Subnet-SP.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(azurerm_public_ip.PublicIP-FE.*.id, count.index)
  }
}

resource "azurerm_virtual_machine" "VM-FE" {
  count                 = var.addFrontEndToFarm ? 1 : 0
  name                  = "VM-${var.vmFE["vmName"]}"
  location              = azurerm_resource_group.resourceGroup.location
  resource_group_name   = azurerm_resource_group.resourceGroup.name
  network_interface_ids = [element(azurerm_network_interface.NIC-FE-0.*.id, count.index)]
  vm_size               = var.vmSP["vmSize"]

  os_profile {
    computer_name  = var.vmFE["vmName"]
    admin_username = var.adminUserName
    admin_password = var.adminPassword
  }

  os_profile_windows_config {
    timezone                  = var.timeZone
    enable_automatic_upgrades = true
    provision_vm_agent        = true
  }

  storage_image_reference {
    publisher = var.vmSP["vmImagePublisher"]
    offer     = var.vmSP["vmImageOffer"]
    sku       = var.vmSP["vmImageSKU"]
    version   = "latest"
  }

  storage_os_disk {
    name              = "Disk-${var.vmFE["vmName"]}-OS"
    managed_disk_type = var.vmSP["storageAccountType"]
    create_option     = "FromImage"
    disk_size_gb      = "128"
    caching           = "ReadWrite"
    os_type           = "Windows"
  }

  storage_data_disk {
    name              = "Disk-${var.vmFE["vmName"]}-Data"
    lun               = 0
    caching           = "ReadWrite"
    create_option     = "Empty"
    disk_size_gb      = 64
    managed_disk_type = var.vmSP["storageAccountType"]
  }
}

resource "azurerm_virtual_machine_extension" "VM-FE-DSC" {
  count                      = var.addFrontEndToFarm ? 1 : 0
  name                       = "VM-${var.vmFE["vmName"]}-DSC"
  location                   = azurerm_resource_group.resourceGroup.location
  resource_group_name        = azurerm_resource_group.resourceGroup.name
  virtual_machine_name       = element(azurerm_virtual_machine.VM-FE.*.name, count.index)
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.9"
  auto_upgrade_minor_version = true
  depends_on                 = [azurerm_virtual_machine_extension.VM-DC-DSC]

  settings = <<SETTINGS
  {
    "wmfVersion": "latest",
    "configuration": {
	    "url": "${var._artifactsLocation}${var.generalSettings["dscScriptsFolder"]}/${var.dscConfigureFEVM["fileName"]}${var._artifactsLocationSasToken}",
	    "function": "${var.dscConfigureFEVM["function"]}",
	    "script": "${var.dscConfigureFEVM["script"]}"
    },
    "configurationArguments": {
      "DNSServer": "${var.networkSettings["vmDCPrivateIPAddress"]}",
      "DomainFQDN": "${var.domainFQDN}",
      "DCName": "${var.vmDC["vmName"]}",
      "SQLName": "${var.vmSQL["vmName"]}",
      "SQLAlias": "${var.generalSettings["sqlAlias"]}"
    },
    "privacy": {
      "dataCollection": "enable"
    }
  }
  
SETTINGS


  protected_settings = <<PROTECTED_SETTINGS
  {
    "configurationArguments": {
      "DomainAdminCreds": {
        "UserName": "${var.adminUserName}",
        "Password": "${var.adminPassword}"
      },
      "SPSetupCreds": {
        "UserName": "${var.generalSettings["spSetupUserName"]}",
        "Password": "${var.serviceAccountsPassword}"
      },
      "SPFarmCreds": {
        "UserName": "${var.generalSettings["spFarmUserName"]}",
        "Password": "${var.serviceAccountsPassword}"
      },
      "SPSvcCreds": {
        "UserName": "${var.generalSettings["spSvcUserName"]}",
        "Password": "${var.serviceAccountsPassword}"
      },
      "SPPassphraseCreds": {
        "UserName": "Passphrase",
        "Password": "${var.serviceAccountsPassword}"
      }
    }
  }
  
PROTECTED_SETTINGS

}

