variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "runner_subnet_id" {
  description = "ID of the runner subnet (from HouseOfVeritas terraform output)"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "listener_vm_size" {
  description = "VM size for the listener (B1ms = 1 vCPU, B2s = 2 vCPUs)"
  type        = string
  default     = "Standard_B1ms"
}

variable "vmss_min_capacity" {
  description = "Minimum VMSS instances (0 for scale-to-zero). Set to 1 to ensure a runner is always warm."
  type        = number
  default     = 1
}

variable "vmss_max_capacity" {
  description = "Maximum VMSS instances for autoscale. Each B1s instance uses 1 vCPU; the listener VM uses 1 (B1ms). Stay within your regional core quota."
  type        = number
  default     = 4

  validation {
    condition     = var.vmss_max_capacity >= 0 && var.vmss_max_capacity <= 10
    error_message = "vmss_max_capacity must be between 0 and 10."
  }
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "runner_version" {
  description = "GitHub Actions runner version"
  type        = string
  default     = "2.332.0"
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH into the listener VM (e.g. your public IP /32). Default is Azure health probe only — SSH is effectively blocked until you set this to your IP."
  type        = string
  default     = "168.63.129.16/32"
}

variable "tags" {
  description = "Additional tags to apply to resources. Must include: project, owner, cost_center. The environment tag is always derived from var.environment."
  type        = map(string)
  default = {
    project     = "actions-runner"
    owner       = "phoenixvc"
    cost_center = "infra"
  }
  validation {
    condition     = contains(keys(var.tags), "project") && contains(keys(var.tags), "owner") && contains(keys(var.tags), "cost_center")
    error_message = "Mandatory tags missing: project, owner, cost_center."
  }
}

variable "alert_email" {
  description = "Email receiver for alert action group"
  type        = string
  default     = ""
}

variable "alert_emails" {
  description = "Email receivers for alert action group"
  type        = list(string)
  default     = []
}

variable "ubuntu_image_version" {
  description = "Ubuntu image version for listener VM and VMSS"
  type        = string
  default     = "latest"
}
