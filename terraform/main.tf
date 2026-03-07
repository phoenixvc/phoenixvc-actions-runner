# Runner infrastructure - Listener VM + VMSS for phoenixvc ephemeral runners
# Deploys into existing subnet (from HouseOfVeritas or similar)

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }

  backend "azurerm" {
    resource_group_name  = "pvc-shared-tfstate-rg-san"
    storage_account_name = "pvctfstatef352fe78c963"
    container_name       = "tfstate"
    key                  = "actions-runner.tfstate"
    use_oidc             = true
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_network_interface" "listener" {
  name                = "${var.environment}-runner-listener-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.runner_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.listener.id
  }

  tags = var.tags
}

resource "azurerm_public_ip" "listener" {
  name                = "${var.environment}-runner-listener-public-ip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

resource "azurerm_network_security_group" "runner-nsg" {
  name                = "${var.environment}-runner-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-ssh-admin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = var.admin_cidr
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "22"
  }

  tags = var.tags
}

resource "azurerm_network_interface_security_group_association" "listener" {
  network_interface_id      = azurerm_network_interface.listener.id
  network_security_group_id = azurerm_network_security_group.runner-nsg.id
}

resource "azurerm_linux_virtual_machine" "listener" {
  name                = "${var.environment}-runner-listener"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.listener_vm_size
  admin_username      = "azureuser"

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
  }

  network_interface_ids = [azurerm_network_interface.listener.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    runner_version = var.runner_version
  }))

  tags = var.tags
}

resource "azurerm_linux_virtual_machine_scale_set" "phoenixvc" {
  name                = "${var.environment}-runner-phoenixvc-vmss"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard_B1s"
  instances           = var.vmss_min_capacity

  admin_username = "azureuser"

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  network_interface {
    name    = "internal"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = var.runner_subnet_id
    }
  }

  upgrade_mode = "Manual"

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}
