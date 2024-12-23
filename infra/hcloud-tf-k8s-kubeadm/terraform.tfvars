node_pools = [
  {
    name     = "controlplane-node-amd64"
    instance = "cx32"
    image    = "debian-12"
    size     = 1
    tags = {
      k8s_control_plane = "true"
      k8s               = "control-plane"
      role              = "control-plane"
    }
    ssh_key_paths = ["~/.ssh/id_rsa.pub", "~/.ssh/cloud-test.pub"]
  },
  {
    name     = "worker-node-amd64"
    instance = "cx22"
    image    = "debian-12"
    size     = 1
    tags = {
      k8s_worker = "true"
      k8s        = "worker"
      role       = "worker"
    }
    ssh_key_paths = ["~/.ssh/id_rsa.pub", "~/.ssh/cloud-test.pub"]
  },
  {
    name     = "worker-node-arm64"
    instance = "cax11"
    image    = "debian-12"
    size     = 1
    tags = {
      k8s_worker = "true"
      k8s        = "worker"
      role       = "worker"
    }
    ssh_key_paths = ["~/.ssh/id_rsa.pub", "~/.ssh/cloud-test.pub"]
  }
]
loadbancers = [
  {
    name = "lb-cp"
    services = [{
      name        = "k8s"
      protocol    = "tcp"
      source_port = 6443
      target_port = 6443
    }]
    targets = [{
      name   = "cp"
      type   = "label_selector"
      target = "k8s_control_plane"
    }]
  }
]

firewall_rules = [
  {
    name           = "block"
    label_selector = "k8s"
  },
  {
    name           = "ssh"
    direction      = "in"
    protocol       = "tcp"
    ports          = "22"
    label_selector = "manager"
  },
  {
    name           = "icmp"
    direction      = "in"
    protocol       = "icmp"
    label_selector = "k8s"
  }
]

per_instance_ipv4 = true
vnet_routes = [{
  name        = "nat-gateway"
  gateway     = "10.0.0.2"
  destination = "0.0.0.0/0"
}]
