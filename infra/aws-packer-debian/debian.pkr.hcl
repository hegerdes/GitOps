packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "debian12" {
  region              = "eu-central-1"
  instance_type       = "t2.micro"
  ssh_username        = "admin" # Depending on the image, this may be "admin" or "debian"

  # Use the source_ami_filter to find the latest AWS-owned Debian 12 AMI
  source_ami_filter {
    filters = {
      name                = "debian-12-amd64-*"
      virtualization-type = "hvm"
    }
    owners      = ["136693071363"]  # AWS's official Debian image owner ID
    most_recent = true
  }

  ami_name = "packer-debian12-{{timestamp}}"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 10
    volume_type           = "gp2"
    delete_on_termination = true
  }
}

build {
  sources = ["source.amazon-ebs.debian12"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "echo 'Hello from Packer!' > /home/admin/hello.txt"
    ]
  }
}
