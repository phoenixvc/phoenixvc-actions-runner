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
  name                = "listener-public-ip"
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
    version   = var.ubuntu_image_version
  }

  identity {
    type = "SystemAssigned"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    runner_version = var.runner_version
  }))

  tags = var.tags

  lifecycle {
    ignore_changes = [custom_data]
  }
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
    version   = var.ubuntu_image_version
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

# --- VMSS Autoscale ---

resource "azurerm_monitor_autoscale_setting" "vmss" {
  name                = "${var.environment}-runner-vmss-autoscale"
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.phoenixvc.id

  profile {
    name = "default"

    capacity {
      default = var.vmss_min_capacity
      minimum = var.vmss_min_capacity
      maximum = var.vmss_max_capacity
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.phoenixvc.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.phoenixvc.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 20
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT10M"
      }
    }
  }

  tags = var.tags
}

# --- Azure Monitor: alert when listener VM is unavailable > 30 min ---

resource "azurerm_monitor_action_group" "runner_alerts" {
  name                = "${var.environment}-runner-alerts"
  resource_group_name = var.resource_group_name
  short_name          = "RunnerAlert"

  tags = var.tags

  dynamic "email_receiver" {
    for_each = concat(var.alert_emails, var.alert_email == "" ? [] : [var.alert_email])
    content {
      name                    = "email-${replace(email_receiver.value, "@", "-")}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }
}

resource "azurerm_monitor_metric_alert" "listener_vm_unavailable" {
  name                = "${var.environment}-listener-vm-unavailable"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_linux_virtual_machine.listener.id]
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT30M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "VmAvailabilityMetric"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }

  action {
    action_group_id = azurerm_monitor_action_group.runner_alerts.id
  }

  tags = var.tags
}

# --- Azure Activity Log Alert: notify on VMSS updates ---
resource "azurerm_monitor_activity_log_alert" "vmss_updates" {
  name                = "${var.environment}-vmss-updates-alert"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_linux_virtual_machine_scale_set.phoenixvc.id]
  description         = "Alert on VMSS write operations (capacity changes and updates)"

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.Compute/virtualMachineScaleSets/write"
  }

  action {
    action_group_id = azurerm_monitor_action_group.runner_alerts.id
  }

  tags = var.tags
}

# --- Azure Activity Log Alert: notify on VMSS scale actions ---
resource "azurerm_monitor_activity_log_alert" "vmss_scale" {
  name                = "${var.environment}-vmss-scale-alert"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_linux_virtual_machine_scale_set.phoenixvc.id]
  description         = "Alert on VMSS scale actions (manual or automated capacity changes)"

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.Compute/virtualMachineScaleSets/scale/action"
  }

  action {
    action_group_id = azurerm_monitor_action_group.runner_alerts.id
  }

  tags = var.tags
}
