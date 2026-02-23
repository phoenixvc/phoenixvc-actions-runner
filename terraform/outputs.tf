output "listener_private_ip" {
  description = "Private IP of the listener VM"
  value       = azurerm_network_interface.listener.private_ip_address
}

output "vmss_name" {
  description = "Name of the phoenixvc runner VMSS"
  value       = azurerm_linux_virtual_machine_scale_set.phoenixvc.name
}
