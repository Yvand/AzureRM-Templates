provider "azurerm" {
  features {}
}

locals {
  config_sp_image = lookup(var.config_sp_image, var.sharepoint_version)
  # source_ip = "10.20.30.40"
  create_rdp_rule = lower(var.rdp_traffic_allowed) == "no" ? 0 : 1
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Create the network security groups
resource "azurerm_network_security_group" "nsg_subnet_dc" {
  name                = "NSG-Subnet-${var.config_dc["vmName"]}"
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
  name                = "NSG-Subnet-${var.config_sql["vmName"]}"
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
  name                = "NSG-Subnet-${var.config_sp["vmName"]}"
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
  address_space       = [var.network_settings["vNetPrivatePrefix"]]
}

# Subnet and NSG for DC
resource "azurerm_subnet" "subnet_dc" {
  name                 = "Subnet-${var.config_dc["vmName"]}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.network_settings["vNetPrivateSubnetDCPrefix"]]
}

resource "azurerm_subnet_network_security_group_association" "nsg_subnetdc_association" {
  subnet_id                 = azurerm_subnet.subnet_dc.id
  network_security_group_id = azurerm_network_security_group.nsg_subnet_dc.id
}

resource "azurerm_subnet" "subnet_sql" {
  name                 = "Subnet-${var.config_sql["vmName"]}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.network_settings["vNetPrivateSubnetSQLPrefix"]]
}

resource "azurerm_subnet_network_security_group_association" "nsg_subnetsql_association" {
  subnet_id                 = azurerm_subnet.subnet_sql.id
  network_security_group_id = azurerm_network_security_group.nsg_subnet_sql.id
}

resource "azurerm_subnet" "subnet_sp" {
  name                 = "Subnet-${var.config_sp["vmName"]}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.network_settings["vNetPrivateSubnetSPPrefix"]]
}

resource "azurerm_subnet_network_security_group_association" "nsg_subnetsp_association" {
  subnet_id                 = azurerm_subnet.subnet_sp.id
  network_security_group_id = azurerm_network_security_group.nsg_subnet_sp.id
}

# Create artifacts for VM DC
resource "azurerm_public_ip" "pip_dc" {
  name                = "PublicIP-${var.config_dc["vmName"]}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  domain_name_label   = "${lower(var.dns_label_prefix)}-${lower(var.config_dc["vmName"])}"
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "nic_dc_0" {
  name                = "NIC-${var.config_dc["vmName"]}-0"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet_dc.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.network_settings["vmDCPrivateIPAddress"]
    public_ip_address_id          = azurerm_public_ip.pip_dc.id
  }
}

# Create artifacts for VM SQL
resource "azurerm_public_ip" "pip_sql" {
  name                = "PublicIP-${var.config_sql["vmName"]}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  domain_name_label   = "${lower(var.dns_label_prefix)}-${lower(var.config_sql["vmName"])}"
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "nic_sql_0" {
  name                = "NIC-${var.config_sql["vmName"]}-0"
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
  name                = "PublicIP-${var.config_sp["vmName"]}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  domain_name_label   = "${lower(var.dns_label_prefix)}-${lower(var.config_sp["vmName"])}"
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "nic_sp_0" {
  name                = "NIC-${var.config_sp["vmName"]}-0"
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
  name                     = "${var.config_dc["vmName"]}"
  computer_name            = var.config_dc["vmName"]
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  network_interface_ids    = [azurerm_network_interface.nic_dc_0.id]
  size                     = var.config_dc["vmSize"]
  admin_username           = var.admin_username
  admin_password           = var.admin_password
  license_type             = "Windows_Server"
  timezone                 = var.time_zone
  enable_automatic_updates = true
  provision_vm_agent       = true

  os_disk {
    name                 = "Disk-${var.config_dc["vmName"]}-OS"
    storage_account_type = var.config_dc["storageAccountType"]
    caching              = "ReadWrite"
  }

  source_image_reference {
    publisher = var.config_dc["vmImagePublisher"]
    offer     = var.config_dc["vmImageOffer"]
    sku       = var.config_dc["vmImageSKU"]
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "vm_dc-DSC" {
  count = 0
  name                       = "VM-${var.config_dc["vmName"]}-DSC"
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
	    "url": "${var._artifactsLocation}${var.general_settings["dscScriptsFolder"]}/${var.config_dc_dsc["fileName"]}${var._artifactsLocationSasToken}",
	    "function": "${var.config_dc_dsc["function"]}",
	    "script": "${var.config_dc_dsc["script"]}"
    },
    "configurationArguments": {
      "domain_fqdn": "${var.domain_fqdn}",
      "PrivateIP": "${var.network_settings["vmDCPrivateIPAddress"]}"
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
        "UserName": "${var.admin_username}",
        "Password": "${var.admin_password}"
      },
      "AdfsSvcCreds": {
        "UserName": "${var.general_settings["adfsSvcUserName"]}",
        "Password": "${var.service_accounts_password}"
      }
    }
  }
PROTECTED_SETTINGS
}

resource "azurerm_windows_virtual_machine" "vm_sql" {
  name                     = "${var.config_sql["vmName"]}"
  computer_name            = var.config_sql["vmName"]
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  network_interface_ids    = [azurerm_network_interface.nic_sql_0.id]
  size                     = var.config_sql["vmSize"]
  admin_username           = "local-${var.admin_username}"
  admin_password           = var.admin_password
  license_type             = "Windows_Server"
  timezone                 = var.time_zone
  enable_automatic_updates = true
  provision_vm_agent       = true

  os_disk {
    name                 = "Disk-${var.config_sql["vmName"]}-OS"
    storage_account_type = var.config_sql["storageAccountType"]
    caching              = "ReadWrite"
  }

  source_image_reference {
    publisher = var.config_sql["vmImagePublisher"]
    offer     = var.config_sql["vmImageOffer"]
    sku       = var.config_sql["vmImageSKU"]
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "vm_sql_dsc" {
  count = 0
  name                       = "VM-${var.config_sql["vmName"]}-DSC"
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
	    "url": "${var._artifactsLocation}${var.general_settings["dscScriptsFolder"]}/${var.config_sql_dsc["fileName"]}${var._artifactsLocationSasToken}",
	    "function": "${var.config_sql_dsc["function"]}",
	    "script": "${var.config_sql_dsc["script"]}"
    },
    "configurationArguments": {
      "DNSServer": "${var.network_settings["vmDCPrivateIPAddress"]}",
      "DomainFQDN": "${var.domain_fqdn}"
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
        "UserName": "${var.admin_username}",
        "Password": "${var.admin_password}"
      },
      "SqlSvcCreds": {
        "UserName": "${var.general_settings["sqlSvcUserName"]}",
        "Password": "${var.service_accounts_password}"
      },
      "SPSetupCreds": {
        "UserName": "${var.general_settings["spSetupUserName"]}",
        "Password": "${var.service_accounts_password}"
      }
    }
  }
PROTECTED_SETTINGS
}

resource "azurerm_windows_virtual_machine" "vm_sp" {
  name                     = "${var.config_sp["vmName"]}"
  computer_name            = var.config_sp["vmName"]
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  network_interface_ids    = [azurerm_network_interface.nic_sp_0.id]
  size                     = var.config_sp["vmSize"]
  admin_username           = "local-${var.admin_username}"
  admin_password           = var.admin_password
  license_type             = "Windows_Server"
  timezone                 = var.time_zone
  enable_automatic_updates = true
  provision_vm_agent       = true

  os_disk {
    name                 = "Disk-${var.config_sp["vmName"]}-OS"
    storage_account_type = var.config_sp["storageAccountType"]
    caching              = "ReadWrite"
  }

  source_image_reference {
    publisher = split(":", local.config_sp_image)[0]
    offer     = split(":", local.config_sp_image)[1]
    sku       = split(":", local.config_sp_image)[2]
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "vm_sp_dsc" {
  count = 0
  name                       = "VM-${var.config_sp["vmName"]}-DSC"
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
	    "url": "${var._artifactsLocation}${var.general_settings["dscScriptsFolder"]}/${var.config_sp_dsc["fileName"]}${var._artifactsLocationSasToken}",
	    "function": "${var.config_sp_dsc["function"]}",
	    "script": "${var.config_sp_dsc["script"]}"
    },
    "configurationArguments": {
      "DNSServer": "${var.network_settings["vmDCPrivateIPAddress"]}",
      "DomainFQDN": "${var.domain_fqdn}",
      "DCName": "${var.config_dc["vmName"]}",
      "SQLName": "${var.config_sql["vmName"]}",
      "SQLAlias": "${var.general_settings["sqlAlias"]}",
      "SharePointVersion": "${var.sharepoint_version}",
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
        "UserName": "${var.admin_username}",
        "Password": "${var.admin_password}"
      },
      "SPSetupCreds": {
        "UserName": "${var.general_settings["spSetupUserName"]}",
        "Password": "${var.service_accounts_password}"
      },
      "SPFarmCreds": {
        "UserName": "${var.general_settings["spFarmUserName"]}",
        "Password": "${var.service_accounts_password}"
      },
      "SPSvcCreds": {
        "UserName": "${var.general_settings["spSvcUserName"]}",
        "Password": "${var.service_accounts_password}"
      },
      "SPAppPoolCreds": {
        "UserName": "${var.general_settings["spAppPoolUserName"]}",
        "Password": "${var.service_accounts_password}"
      },
      "SPPassphraseCreds": {
        "UserName": "Passphrase",
        "Password": "${var.service_accounts_password}"
      },
      "SPSuperUserCreds": {
        "UserName": "${var.general_settings["spSuperUserName"]}",
        "Password": "${var.service_accounts_password}"
      },
      "SPSuperReaderCreds": {
        "UserName": "${var.general_settings["spSuperReaderName"]}",
        "Password": "${var.service_accounts_password}"
      }
    }
  }
PROTECTED_SETTINGS
}

# Can create 0 to var.number_additional_frontend FE VMs
resource "azurerm_public_ip" "pip_fe" {
  count               = var.number_additional_frontend
  name                = "PublicIP-${var.config_fe["vmName"]}-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  domain_name_label   = "${lower(var.dns_label_prefix)}-${lower(var.config_fe["vmName"])}-${count.index}"
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "nic_fe_0" {
  count               = var.number_additional_frontend
  name                = "NIC-${var.config_fe["vmName"]}-${count.index}-0"
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
  count                    = var.number_additional_frontend
  name                     = "${var.config_fe["vmName"]}-${count.index}"
  computer_name            = "${var.config_fe["vmName"]}-${count.index}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  network_interface_ids    = [element(azurerm_network_interface.nic_fe_0.*.id, count.index)]
  size                     = var.config_sp["vmSize"]
  admin_username           = "local-${var.admin_username}"
  admin_password           = var.admin_password
  license_type             = "Windows_Server"
  timezone                 = var.time_zone
  enable_automatic_updates = true
  provision_vm_agent       = true

  os_disk {
    name                 = "Disk-${var.config_fe["vmName"]}-${count.index}-OS"
    storage_account_type = var.config_sp["storageAccountType"]
    caching              = "ReadWrite"
  }

  source_image_reference {
    publisher = split(":", local.config_sp_image)[0]
    offer     = split(":", local.config_sp_image)[1]
    sku       = split(":", local.config_sp_image)[2]
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "vm_fe_dsc" {
  # count                      = var.number_additional_frontend
  count                      = 0
  name                       = "VM-${var.config_fe["vmName"]}-${count.index}-DSC"
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
	    "url": "${var._artifactsLocation}${var.general_settings["dscScriptsFolder"]}/${var.config_fe_dsc["fileName"]}${var._artifactsLocationSasToken}",
	    "function": "${var.config_fe_dsc["function"]}",
	    "script": "${var.config_fe_dsc["script"]}"
    },
    "configurationArguments": {
      "DNSServer": "${var.network_settings["vmDCPrivateIPAddress"]}",
      "DomainFQDN": "${var.domain_fqdn}",
      "DCName": "${var.config_dc["vmName"]}",
      "SQLName": "${var.config_sql["vmName"]}",
      "SQLAlias": "${var.general_settings["sqlAlias"]}",
      "SharePointVersion": "${var.sharepoint_version}",
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
        "UserName": "${var.admin_username}",
        "Password": "${var.admin_password}"
      },
      "SPSetupCreds": {
        "UserName": "${var.general_settings["spSetupUserName"]}",
        "Password": "${var.service_accounts_password}"
      },
      "SPFarmCreds": {
        "UserName": "${var.general_settings["spFarmUserName"]}",
        "Password": "${var.service_accounts_password}"
      },
      "SPPassphraseCreds": {
        "UserName": "Passphrase",
        "Password": "${var.service_accounts_password}"
      }
    }
  }
PROTECTED_SETTINGS
}
