node_pools = [
  {
    name     = "controlplane-node-arm64"
    instance = "cax21"
    image    = "k8s-v1.35.0-debian-13-arm64"
    # image = "debian-13"
    size = 1
    tags = {
      k8s_control_plane = "true"
      k8s               = "control-plane"
      role              = "control-plane"
    }
    ssh_key_paths = ["~/.ssh/id_rsa.pub", "~/.ssh/cloud-test.pub"]
    ipv4_enabled  = true
  },
  {
    name     = "worker-node-amd64"
    instance = "cx23"
    image    = "k8s-v1.35.0-debian-13-amd64"
    # image = "debian-13"
    size = 1
    tags = {
      k8s_worker = "true"
      k8s        = "worker"
      role       = "worker"
    }
    ssh_key_paths = ["~/.ssh/id_rsa.pub", "~/.ssh/cloud-test.pub"]
    ipv4_enabled  = true
  },
  {
    name     = "worker-node-arm64"
    instance = "cax11"
    image    = "k8s-v1.35.0-debian-13-arm64"
    # image = "debian-13"
    size = 1
    tags = {
      k8s_worker = "true"
      k8s        = "worker"
      role       = "worker"
    }
    ssh_key_paths = ["~/.ssh/id_rsa.pub", "~/.ssh/cloud-test.pub"]
    ipv4_enabled  = true
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
    name            = "block"
    label_selectors = ["k8s"]
  },
  {
    name            = "ssh"
    direction       = "in"
    protocol        = "tcp"
    ports           = "22"
    label_selectors = ["manager"]
  },
  {
    name            = "icmp"
    direction       = "in"
    protocol        = "icmp"
    label_selectors = ["k8s"]
  }
]

# vnet_routes = [{
#   name        = "nat-gateway"
#   gateway     = "10.0.0.2"
#   destination = "0.0.0.0/0"
# }]
