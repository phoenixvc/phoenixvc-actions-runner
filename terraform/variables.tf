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
  description = "VM size for the listener"
  type        = string
  default     = "Standard_B2s"
}

variable "vmss_min_capacity" {
  description = "Minimum VMSS instances (0 for scale-to-zero)"
  type        = number
  default     = 0
}

variable "vmss_max_capacity" {
  description = "Maximum VMSS instances for autoscale"
  type        = number
  default     = 4
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
  description = "Tags to apply to resources (must include: environment, project, owner, cost_center)"
  type        = map(string)
  default = {
    environment = "prod"
    project     = "actions-runner"
    owner       = "phoenixvc"
    cost_center = "infra"
  }
  validation {
    condition     = contains(keys(var.tags), "environment") && contains(keys(var.tags), "project") && contains(keys(var.tags), "owner") && contains(keys(var.tags), "cost_center")
    error_message = "Mandatory tags missing: environment, project, owner, cost_center."
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
