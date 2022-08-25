provider "azurerm" {
  features {}
}

locals {
  vmSP_image = lookup(var.vmSP_image, var.sharePointVersion)
  # source_ip = "10.20.30.40"
  create_rdp_rule = lower(var.rdp_traffic_allowed) == "no" ? 0 : 1
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = var.resourceGroupName
  location = var.location
}

# Create the network security groups
resource "azurerm_network_security_group" "nsg_subnet_dc" {
  name                = "NSG-Subnet-${var.vmDC["vmName"]}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "rdp_rule_subnet_dc" {
 count = local.create_rdp_rule
    name                       = "allow-rdp-rule"
    description                = "Allow RDP"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.rdp_traffic_allowed
    destination_address_prefix = "*"
    access                     = "Allow"
    priority                   = 100
    direction                  = "Inbound"
  resource_group_name = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_subnet_dc.name
}

resource "azurerm_network_security_group" "nsg_subnet_sql" {
  name                = "NSG-Subnet-${var.vmSQL["vmName"]}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "rdp_rule_subnet_sql" {
 count = local.create_rdp_rule
    name                       = "allow-rdp-rule"
    description                = "Allow RDP"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.rdp_traffic_allowed
    destination_address_prefix = "*"
    access                     = "Allow"
    priority                   = 100
    direction                  = "Inbound"
  resource_group_name = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_subnet_sql.name
}

resource "azurerm_network_security_group" "nsg_subnet_sp" {
  name                = "NSG-Subnet-${var.vmSP["vmName"]}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "rdp_rule_subnet_sp" {
 count = local.create_rdp_rule
    name                       = "allow-rdp-rule"
    description                = "Allow RDP"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.rdp_traffic_allowed
    destination_address_prefix = "*"
    access                     = "Allow"
    priority                   = 100
    direction                  = "Inbound"
  resource_group_name = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_subnet_sp.name
}

# Create the virtual network, 3 subnets, and associate each subnet with its Network Security Group
resource "azurerm_virtual_network" "vnet" {
  name                = "${azurerm_resource_group.rg.name}-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [var.networkSettings["vNetPrivatePrefix"]]
}

# Subnet and NSG for DC
resource "azurerm_subnet" "subnet_dc" {
  name                 = "Subnet-${var.vmDC["vmName"]}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.networkSettings["vNetPrivateSubnetDCPrefix"]]
}

resource "azurerm_subnet_network_security_group_association" "nsg_subnetdc_association" {
  subnet_id                 = azurerm_subnet.subnet_dc.id
  network_security_group_id = azurerm_network_security_group.nsg_subnet_dc.id
}

resource "azurerm_subnet" "subnet_sql" {
  name                 = "Subnet-${var.vmSQL["vmName"]}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.networkSettings["vNetPrivateSubnetSQLPrefix"]]
}

resource "azurerm_subnet_network_security_group_association" "nsg_subnetsql_association" {
  subnet_id                 = azurerm_subnet.subnet_sql.id
  network_security_group_id = azurerm_network_security_group.nsg_subnet_sql.id
}

resource "azurerm_subnet" "subnet_sp" {
  name                 = "Subnet-${var.vmSP["vmName"]}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.networkSettings["vNetPrivateSubnetSPPrefix"]]
}

resource "azurerm_subnet_network_security_group_association" "nsg_subnetsp_association" {
  subnet_id                 = azurerm_subnet.subnet_sp.id
  network_security_group_id = azurerm_network_security_group.nsg_subnet_sp.id
}

# Create artifacts for VM DC
resource "azurerm_public_ip" "pip_dc" {
  name                = "PublicIP-${var.vmDC["vmName"]}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  domain_name_label   = "${lower(var.dnsLabelPrefix)}-${lower(var.vmDC["vmName"])}"
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "nic_dc_0" {
  name                = "NIC-${var.vmDC["vmName"]}-0"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet_dc.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.networkSettings["vmDCPrivateIPAddress"]
    public_ip_address_id          = azurerm_public_ip.pip_dc.id
  }
}

# Create artifacts for VM SQL
resource "azurerm_public_ip" "pip_sql" {
  name                = "PublicIP-${var.vmSQL["vmName"]}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  domain_name_label   = "${lower(var.dnsLabelPrefix)}-${lower(var.vmSQL["vmName"])}"
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "nic_sql_0" {
  name                = "NIC-${var.vmSQL["vmName"]}-0"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet_sql.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip_sql.id
  }
}

# Create artifacts for VM SP
resource "azurerm_public_ip" "pip_sp" {
  name                = "PublicIP-${var.vmSP["vmName"]}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  domain_name_label   = "${lower(var.dnsLabelPrefix)}-${lower(var.vmSP["vmName"])}"
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "nic_sp_0" {
  name                = "NIC-${var.vmSP["vmName"]}-0"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet_sp.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip_sp.id
  }
}

# Create virtual machines
resource "azurerm_windows_virtual_machine" "vm_dc" {
  name                     = "${var.vmDC["vmName"]}"
  computer_name            = var.vmDC["vmName"]
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  network_interface_ids    = [azurerm_network_interface.nic_dc_0.id]
  size                     = var.vmDC["vmSize"]
  admin_username           = var.adminUserName
  admin_password           = var.adminPassword
  license_type             = "Windows_Server"
  timezone                 = var.timeZone
  enable_automatic_updates = true
  provision_vm_agent       = true

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

resource "azurerm_virtual_machine_extension" "vm_dc-DSC" {
  count = 0
  name                       = "VM-${var.vmDC["vmName"]}-DSC"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm_dc.id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.9"
  auto_upgrade_minor_version = true

  timeouts {
    create = "30m"
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

resource "azurerm_windows_virtual_machine" "vm_sql" {
  name                     = "${var.vmSQL["vmName"]}"
  computer_name            = var.vmSQL["vmName"]
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  network_interface_ids    = [azurerm_network_interface.nic_sql_0.id]
  size                     = var.vmSQL["vmSize"]
  admin_username           = "local-${var.adminUserName}"
  admin_password           = var.adminPassword
  license_type             = "Windows_Server"
  timezone                 = var.timeZone
  enable_automatic_updates = true
  provision_vm_agent       = true

  os_disk {
    name                 = "Disk-${var.vmSQL["vmName"]}-OS"
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

resource "azurerm_virtual_machine_extension" "vm_sql_dsc" {
  count = 0
  name                       = "VM-${var.vmSQL["vmName"]}-DSC"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm_sql.id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.9"
  auto_upgrade_minor_version = true

  timeouts {
    create = "30m"
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

resource "azurerm_windows_virtual_machine" "vm_sp" {
  name                     = "${var.vmSP["vmName"]}"
  computer_name            = var.vmSP["vmName"]
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  network_interface_ids    = [azurerm_network_interface.nic_sp_0.id]
  size                     = var.vmSP["vmSize"]
  admin_username           = "local-${var.adminUserName}"
  admin_password           = var.adminPassword
  license_type             = "Windows_Server"
  timezone                 = var.timeZone
  enable_automatic_updates = true
  provision_vm_agent       = true

  os_disk {
    name                 = "Disk-${var.vmSP["vmName"]}-OS"
    storage_account_type = var.vmSP["storageAccountType"]
    caching              = "ReadWrite"
  }

  source_image_reference {
    publisher = split(":", local.vmSP_image)[0]
    offer     = split(":", local.vmSP_image)[1]
    sku       = split(":", local.vmSP_image)[2]
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "vm_sp_dsc" {
  count = 0
  name                       = "VM-${var.vmSP["vmName"]}-DSC"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm_sp.id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.9"
  auto_upgrade_minor_version = true

  timeouts {
    create = "75m"
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
      "SharePointVersion": "${var.sharePointVersion}",
      "EnableAnalysis": true
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
resource "azurerm_public_ip" "pip_fe" {
  count               = var.numberOfAdditionalFrontEnd
  name                = "PublicIP-${var.vmFE["vmName"]}-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  domain_name_label   = "${lower(var.dnsLabelPrefix)}-${lower(var.vmFE["vmName"])}-${count.index}"
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "nic_fe_0" {
  count               = var.numberOfAdditionalFrontEnd
  name                = "NIC-${var.vmFE["vmName"]}-${count.index}-0"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet_sp.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(azurerm_public_ip.pip_fe.*.id, count.index)
  }
}

resource "azurerm_windows_virtual_machine" "vm_fe" {
  count                    = var.numberOfAdditionalFrontEnd
  name                     = "${var.vmFE["vmName"]}-${count.index}"
  computer_name            = "${var.vmFE["vmName"]}-${count.index}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  network_interface_ids    = [element(azurerm_network_interface.nic_fe_0.*.id, count.index)]
  size                     = var.vmSP["vmSize"]
  admin_username           = "local-${var.adminUserName}"
  admin_password           = var.adminPassword
  license_type             = "Windows_Server"
  timezone                 = var.timeZone
  enable_automatic_updates = true
  provision_vm_agent       = true

  os_disk {
    name                 = "Disk-${var.vmFE["vmName"]}-${count.index}-OS"
    storage_account_type = var.vmSP["storageAccountType"]
    caching              = "ReadWrite"
  }

  source_image_reference {
    publisher = split(":", local.vmSP_image)[0]
    offer     = split(":", local.vmSP_image)[1]
    sku       = split(":", local.vmSP_image)[2]
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "vm_fe_dsc" {
  # count                      = var.numberOfAdditionalFrontEnd
  count                      = 0
  name                       = "VM-${var.vmFE["vmName"]}-${count.index}-DSC"
  virtual_machine_id         = element(azurerm_windows_virtual_machine.vm_fe.*.id, count.index)
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
      "SharePointVersion": "${var.sharePointVersion}",
      "EnableAnalysis": true
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
