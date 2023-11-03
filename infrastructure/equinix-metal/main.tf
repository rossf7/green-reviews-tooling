terraform {
  required_providers {
    equinix = {
      source  = "equinix/equinix"
      version = "1.13.0"
    }
  }
}

provider "equinix" {
  auth_token = var.equinix_auth_token
}

resource "equinix_metal_device" "control_plane" {
  hostname         = "${var.cluster_name}-control-plane"
  plan             = var.device_plan
  metro            = var.device_metro
  operating_system = var.device_os
  billing_cycle    = "hourly"
  project_id       = var.project_id

  behavior {
    allow_changes = ["user_data"]
  }

  user_data = <<EOF
apt update
apt install software-properties-common
add-apt-repository --yes --update ppa:ansible/ansible
apt install ansible
EOF
}
