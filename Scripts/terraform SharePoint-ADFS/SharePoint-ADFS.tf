# Configure the Microsoft Azure Provider
provider "azurerm" {
  # We recommend pinning to the specific version of the Azure Provider you're using
  # since new versions are released frequently
  version = "=2.28.0"

  features {}

  # More information on the authentication methods supported by
  # the AzureRM Provider can be found here:
  # http://terraform.io/docs/providers/azurerm/index.html

  # subscription_id = "..."
  # client_id       = "..."
  # client_secret   = "..."
  # tenant_id       = "..."
}


# Create a resource group
resource "azurerm_resource_group" "resourceGroup" {
  name     = var.resourceGroupName
  location = var.location
}

# Create network security groups
resource "azurerm_network_security_group" "NSG-Subnet-DC" {
  name                = "NSG-Subnet-${var.vmDC["vmName"]}"
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
    priority                   = 110
    direction                  = "Inbound"
  }
}

resource "azurerm_network_security_group" "NSG-Subnet-SQL" {
  name                = "NSG-Subnet-${var.vmSQL["vmName"]}"
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
    priority                   = 110
    direction                  = "Inbound"
  }
}

resource "azurerm_network_security_group" "NSG-Subnet-SP" {
  name                = "NSG-Subnet-${var.vmSP["vmName"]}"
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
    priority                   = 110
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
  address_prefixes     = [var.networkSettings["vNetPrivateSubnetDCPrefix"]]
}

resource "azurerm_subnet_network_security_group_association" "nsg_subnetdc_association" {
  subnet_id                 = azurerm_subnet.Subnet-DC.id
  network_security_group_id = azurerm_network_security_group.NSG-Subnet-DC.id
}

# Subnet and NSG for SQL
# # Delay subnet creation to workaround bug https://github.com/terraform-providers/terraform-provider-azurerm/issues/2758
# resource "null_resource" "delay_subnet_sql" {
#   provisioner "local-exec" {
#     command = "ping 127.0.0.1 -n 6 > nul"
#   }

#   triggers = {
#     "before" = "${azurerm_subnet.Subnet-DC.id}"
#   }
# }

resource "azurerm_subnet" "Subnet-SQL" {
  name                 = "Subnet-${var.vmSQL["vmName"]}"
  resource_group_name  = azurerm_resource_group.resourceGroup.name
  virtual_network_name = azurerm_virtual_network.VNet.name
  address_prefixes       = [var.networkSettings["vNetPrivateSubnetSQLPrefix"]]
  # depends_on                = [null_resource.delay_subnet_sql]
}

resource "azurerm_subnet_network_security_group_association" "nsg_subnetsql_association" {
  subnet_id                 = azurerm_subnet.Subnet-SQL.id
  network_security_group_id = azurerm_network_security_group.NSG-Subnet-SQL.id
}

# Subnet and NSG for SP
# # Delay subnet creation to workaround bug https://github.com/terraform-providers/terraform-provider-azurerm/issues/2758
# resource "null_resource" "delay_subnet_sp" {
#   provisioner "local-exec" {
#     command = "ping 127.0.0.1 -n 6 > nul"
#   }

#   triggers = {
#     "before" = "${azurerm_subnet.Subnet-SQL.id}"
#   }
# }

resource "azurerm_subnet" "Subnet-SP" {
  name                 = "Subnet-${var.vmSP["vmName"]}"
  resource_group_name  = azurerm_resource_group.resourceGroup.name
  virtual_network_name = azurerm_virtual_network.VNet.name
  address_prefixes       = [var.networkSettings["vNetPrivateSubnetSPPrefix"]]
  # depends_on                = [null_resource.delay_subnet_sp]
}

resource "azurerm_subnet_network_security_group_association" "nsg_subnetsp_association" {
  subnet_id                 = azurerm_subnet.Subnet-SP.id
  network_security_group_id = azurerm_network_security_group.NSG-Subnet-SP.id
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
resource "azurerm_windows_virtual_machine" "VM-DC" {
  name                  = "VM-${var.vmDC["vmName"]}"
  computer_name = var.vmDC["vmName"]
  location              = azurerm_resource_group.resourceGroup.location
  resource_group_name   = azurerm_resource_group.resourceGroup.name
  network_interface_ids = [azurerm_network_interface.NIC-DC-0.id]
  size                  = var.vmDC["vmSize"]
  admin_username        = var.adminUserName
  admin_password        = var.adminPassword
  license_type = "Windows_Server"
  timezone                  = var.timeZone
  enable_automatic_updates  = true
  provision_vm_agent        = true

  os_disk {
    name                 = "Disk-${var.vmDC["vmName"]}-OS"
    storage_account_type = var.vmDC["storageAccountType"]
    caching              = "ReadWrite"
  }

  source_image_reference {
    publisher = var.vmDC["vmImagePublisher"]
    offer     = var.vmDC["vmImageOffer"]
    sku       = var.vmDC["vmImageSKU"]
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "VM-DC-DSC" {
  name                       = "VM-${var.vmDC["vmName"]}-DSC"
  virtual_machine_id       = azurerm_windows_virtual_machine.VM-DC.id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.9"
  auto_upgrade_minor_version = true

  timeouts {
    create = "45m"
  }

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

resource "azurerm_windows_virtual_machine" "VM-SQL" {
  name                  = "VM-${var.vmSQL["vmName"]}"
  computer_name = var.vmSQL["vmName"]
  location              = azurerm_resource_group.resourceGroup.location
  resource_group_name   = azurerm_resource_group.resourceGroup.name
  network_interface_ids = [azurerm_network_interface.NIC-SQL-0.id]
  size               = var.vmSQL["vmSize"]
  admin_username        = var.adminUserName
  admin_password        = var.adminPassword
  license_type = "Windows_Server"
  timezone                  = var.timeZone
  enable_automatic_updates  = true
  provision_vm_agent        = true

  os_disk {
    name              = "Disk-${var.vmSQL["vmName"]}-OS"
    storage_account_type = var.vmSQL["storageAccountType"]
    caching              = "ReadWrite"
  }

  source_image_reference {
    publisher = var.vmSQL["vmImagePublisher"]
    offer     = var.vmSQL["vmImageOffer"]
    sku       = var.vmSQL["vmImageSKU"]
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "VM-SQL-DSC" {
  name                       = "VM-${var.vmSQL["vmName"]}-DSC"
  virtual_machine_id       = azurerm_windows_virtual_machine.VM-SQL.id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.9"
  auto_upgrade_minor_version = true

  timeouts {
    create = "45m"
  }

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

resource "azurerm_windows_virtual_machine" "VM-SP" {
  name                  = "VM-${var.vmSP["vmName"]}"
  computer_name = var.vmSP["vmName"]
  location              = azurerm_resource_group.resourceGroup.location
  resource_group_name   = azurerm_resource_group.resourceGroup.name
  network_interface_ids = [azurerm_network_interface.NIC-SP-0.id]
  size               = var.vmSP["vmSize"]
  admin_username        = var.adminUserName
  admin_password        = var.adminPassword
  license_type = "Windows_Server"
  timezone                  = var.timeZone
  enable_automatic_updates  = true
  provision_vm_agent        = true

  os_disk {
    name                 = "Disk-${var.vmSP["vmName"]}-OS"
    storage_account_type = var.vmSP["storageAccountType"]
    caching              = "ReadWrite"
  }

  source_image_reference {
    publisher = var.vmSP["vmImagePublisher"]
    offer     = var.vmSP["vmImageOffer"]
    sku       = "sp${var.sharePointVersion}"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "VM-SP-DSC" {
  name                       = "VM-${var.vmSP["vmName"]}-DSC"
  virtual_machine_id       = azurerm_windows_virtual_machine.VM-SP.id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.9"
  auto_upgrade_minor_version = true

  timeouts {
    create = "90m"
  }

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

# Can create 0 to var.numberOfAdditionalFrontEnd FE VMs
resource "azurerm_public_ip" "PublicIP-FE" {
  count               = var.numberOfAdditionalFrontEnd
  name                = "PublicIP-${var.vmFE["vmName"]}-${count.index}"
  location            = azurerm_resource_group.resourceGroup.location
  resource_group_name = azurerm_resource_group.resourceGroup.name
  domain_name_label   = "${lower(var.dnsLabelPrefix)}-${lower(var.vmFE["vmName"])}-${count.index}"
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "NIC-FE-0" {
  count               = var.numberOfAdditionalFrontEnd
  name                = "NIC-${var.vmFE["vmName"]}-${count.index}-0"
  location            = azurerm_resource_group.resourceGroup.location
  resource_group_name = azurerm_resource_group.resourceGroup.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.Subnet-SP.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(azurerm_public_ip.PublicIP-FE.*.id, count.index)
  }
}

resource "azurerm_windows_virtual_machine" "VM-FE" {
  count                 = var.numberOfAdditionalFrontEnd
  name                  = "VM-${var.vmFE["vmName"]}-${count.index}"
  computer_name         = "${var.vmFE["vmName"]}-${count.index}"
  location              = azurerm_resource_group.resourceGroup.location
  resource_group_name   = azurerm_resource_group.resourceGroup.name
  network_interface_ids = [element(azurerm_network_interface.NIC-FE-0.*.id, count.index)]
  size                  = var.vmSP["vmSize"]
  admin_username        = var.adminUserName
  admin_password        = var.adminPassword
  license_type = "Windows_Server"
  timezone                  = var.timeZone
  enable_automatic_updates  = true
  provision_vm_agent        = true

  os_disk {
    name                 = "Disk-${var.vmFE["vmName"]}-${count.index}-OS"
    storage_account_type = var.vmSP["storageAccountType"]
    caching              = "ReadWrite"
  }

  source_image_reference {
    publisher = var.vmSP["vmImagePublisher"]
    offer     = var.vmSP["vmImageOffer"]
    sku       = "sp${var.sharePointVersion}"
    version   = "latest"
  }  
}

resource "azurerm_virtual_machine_extension" "VM-FE-DSC" {
  count                      = var.numberOfAdditionalFrontEnd
  name                       = "VM-${var.vmFE["vmName"]}-${count.index}-DSC"
  virtual_machine_id       = element(azurerm_windows_virtual_machine.VM-FE.*.id, count.index)
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.9"
  auto_upgrade_minor_version = true

  timeouts {
    create = "90m"
  }

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
      "SPPassphraseCreds": {
        "UserName": "Passphrase",
        "Password": "${var.serviceAccountsPassword}"
      }
    }
  }
PROTECTED_SETTINGS
}
