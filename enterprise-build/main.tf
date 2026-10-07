# main.tf: Phase 1, providers and student_name

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "docker" {
  # Local Docker daemon on the hypervisor host. No extra config needed.
}

provider "libvirt" {
  uri = "qemu:///system"
}

variable "student_name" {
  type        = string
  description = "Your student identifier (e.g., jsmith, mgarcia)"

  validation {
    condition     = can(regex("^[a-z]{2,10}$", var.student_name))
    error_message = "Student name must be 2-10 lowercase letters."
  }
}

# main.tf: Phase 2, variables and locals

variable "services" {
  description = "Docker services on the host. Key = short name (gitea, wordpress)."
  type = map(object({
    image   = string
    network = string
    ports = optional(list(object({
      internal = number
      external = number
    })), [])
    env = optional(map(string), {})
  }))
  default = {}
}

variable "vms" {
  description = "KVM virtual machines. Key = domain name (prefix with student_name)."
  type = map(object({
    os        = string
    memory_mb = optional(number)
    vcpu      = optional(number)
  }))
  default = {}

  validation {
    condition = alltrue([
      for v in values(var.vms) :
      contains(["win-server", "win11", "ubuntu-server"], v.os)
    ])
    error_message = "OS must be one of: win-server, win11, ubuntu-server"
  }
}

variable "networks" {
  description = "Docker network segments. Each becomes student_name-NAME-net"
  type        = list(string)
  default     = ["devops", "internal", "web"]
}

variable "corp_octet" {
  description = "Third octet of the KVM NAT subnet (192.168.CORP_OCTET.0/24). Student A: 50. Student B: 51."
  type        = number
  default     = 50

  validation {
    condition     = var.corp_octet >= 1 && var.corp_octet <= 254
    error_message = "corp_octet must be between 1 and 254."
  }
}

variable "cloud_image_path" {
  description = "Path to the Ubuntu cloud image on the hypervisor host"
  type        = string
  default     = "/opt/images/ubuntu-26.04-server-cloudimg-amd64.img"
}

variable "win_server_image_path" {
  description = "Path to the golden Windows Server qcow2 on the hypervisor host"
  type        = string
  default     = "/opt/images/orig/windows-server-2022.qcow2"
}

variable "win11_image_path" {
  description = "Path to the golden Windows 11 qcow2 on the hypervisor host"
  type        = string
  default     = "/opt/images/orig/aliyah-win11.qcow2"
}

locals {
  os_defaults = {
    win-server = {
      image      = var.win_server_image_path
      vcpu       = 2
      memory_mb  = 2048
      disk_bus   = "sata"
      disk_dev   = "sda"
      nic        = "e1000e"
      uefi       = true
      loader     = "/usr/share/OVMF/OVMF_CODE_4M.ms.fd"
      nvram_tmpl = "/usr/share/OVMF/OVMF_VARS_4M.ms.fd"
      cloud_init = false
    }
    win11 = {
      image      = var.win11_image_path
      vcpu       = 4
      memory_mb  = 4096
      disk_bus   = "sata"
      disk_dev   = "sda"
      nic        = "e1000e"
      uefi       = true
      loader     = "/usr/share/OVMF/OVMF_CODE_4M.ms.fd"
      nvram_tmpl = "/usr/share/OVMF/OVMF_VARS_4M.ms.fd"
      cloud_init = false
    }
    ubuntu-server = {
      image      = var.cloud_image_path
      vcpu       = 2
      memory_mb  = 2048
      disk_bus   = "virtio"
      disk_dev   = "vda"
      nic        = "virtio"
      uefi       = false
      loader     = null
      nvram_tmpl = null
      cloud_init = true
    }
  }

  # Merged VM map: student overrides win, profile defaults fill the rest
  vms = { for name, cfg in var.vms : name => {
    os         = cfg.os
    image      = local.os_defaults[cfg.os].image
    memory     = (coalesce(cfg.memory_mb, local.os_defaults[cfg.os].memory_mb)) * 1024
    vcpu       = coalesce(cfg.vcpu, local.os_defaults[cfg.os].vcpu)
    disk_bus   = local.os_defaults[cfg.os].disk_bus
    disk_dev   = local.os_defaults[cfg.os].disk_dev
    nic        = local.os_defaults[cfg.os].nic
    uefi       = local.os_defaults[cfg.os].uefi
    loader     = local.os_defaults[cfg.os].loader
    nvram_tmpl = local.os_defaults[cfg.os].nvram_tmpl
    cloud_init = local.os_defaults[cfg.os].cloud_init
  } }
}
