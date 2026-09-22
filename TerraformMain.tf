# main.tf - Windows Server 2025 via libvirt provider
terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
      version = "~> 0.9"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

variable "student_name" {
  type = string
  description = "Your student identifier (e.g., jsmith, mgarcia)"

  validation {
    condition = can(regex("^[a-z]{2,10}$", var.student_name))
    error_message = "Student name must be 2-10 lowercase letters."
  }
}

variable "cpu_cores" {
  description = "Number of CPU cores"
  type = number
  default = 4
}

variable "ram_size" {
  description = "RAM in KiB (2097152 = 2 GB)"
  type = number
  default = 2097152
}

variable "image_path" {
  description = "URL or path to the qcow2 base image"
  type = string
  default = "/opt/images/win2k25.qcow2"
}
variable "vm_name" {
  description = "Name of the virtual machine"
  type = string
  default = "dc1"
}
resource "terraform_data" "disk" {
  input = {
    name = "${var.student_name}-${var.vm_name}"
    image = var.image_path
  }

  provisioner "local-exec" {
    command = "sudo cp ${var.image_path}
/var/lib/libvirt/images/${var.student_name}-${var.vm_name}.qcow2"
  }

  provisioner "local-exec" {
    when = destroy
    command = "sudo rm -f /var/lib/libvirt/images/${self.input.name}.qcow2"
  }
}
resource "libvirt_domain" "windows_server" {
  name = "${var.student_name}-${var.vm_name}"
  memory = var.ram_size
  memory_unit = "KiB"
  vcpu = var.cpu_cores
  type = "kvm"
  autostart = true
  
  cpu = {
    mode = "host-passthrough"
  }

  os = {
    type = "hvm"
    type_arch = "x86_64"
    type_machine = "q35"
    boot_devices = [{ dev = "hd" }]
  }
  features = {
    acpi = true
    apic = {}
  }
  devices = {
  disks = [
    {
      source = {
        file = {
          file = "/var/lib/libvirt/images/${var.student_name}-${var.vm_name}.qcow2"
        }
      }
      driver = {
        type = "qcow2"
      }
      target = {
        dev = "sda"
        bus = "sata"
      }
    }
  ]

  interfaces = [
    {
      source = {
        network = {
          network = "default"
        }
      }
      model = {
        type = "e1000e"
      }
    }
  ]

  graphics = [
    {
      spice = {
        auto_port = true
        listen = "0.0.0.0"
      }
    }
  ]

  serials = [
    {
      type = "pty"
    }
  ]  

  consoles = [
    {
      type = "pty"
      target = {
        type = "serial"
        port = 0
        }
      }
    ]
  }

  depends_on = [
    terraform_data.disk
  ]
}

output "vm_name" {
  value = "${var.student_name}-${var.vm_name}"
}

output "vnc_display" {
  value = "virsh vncdisplay ${var.student_name}-${var.vm_name}"
}
