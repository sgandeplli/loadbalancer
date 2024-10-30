provider "google" {
  project = "primal-gear-436812-t0"
}

resource "google_compute_instance_template" "default" {
  name           = "apache-instance-template1"
  machine_type   = "e2-medium"

  disk {
    auto_delete  = true
    boot         = true
    source_image = "centos-cloud/centos-stream-9"
  }

  network_interface {
    network = "default"
    access_config {}
  }
  metadata = {
    ssh-keys = "centos:${file("/root/.ssh/id_rsa.pub")}"
    }
  }
  output "ssh_key" {
    value = file("/root/.ssh/id_rsa.pub")
  }


resource "google_compute_instance_group_manager" "default" {
  name               = "apache-instance-group1"
  version {
    instance_template = google_compute_instance_template.default.id
  }
  base_instance_name = "apache-instance"
  target_size        = 2
  zone               = "us-central1-a"

  named_port {
    name = "http"
    port = 80
  }
}

resource "google_compute_backend_service" "default" {
  name                  = "apache-backend-service1"
  backend {
    group = google_compute_instance_group_manager.default.instance_group
  }
  health_checks         = [google_compute_http_health_check.default.id]
  port_name             = "http"
  protocol              = "HTTP"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL"
}

resource "google_compute_http_health_check" "default" {
  name                    = "apache-health-check1"
  request_path            = "/"
  port                    = 80
  check_interval_sec      = 20
  timeout_sec             = 15
  healthy_threshold       = 1
  unhealthy_threshold     = 3
}

resource "google_compute_url_map" "default" {
  name            = "apache-url-map1"
  default_service = google_compute_backend_service.default.id
}

resource "google_compute_target_http_proxy" "default" {
  name    = "apache-http-proxy1"
  url_map = google_compute_url_map.default.id
}

resource "google_compute_global_forwarding_rule" "default" {
  name       = "apache-forwarding-rule1"
  target     = google_compute_target_http_proxy.default.id
  port_range = "80"
}

resource "google_compute_global_address" "lb_ip" {
  name = "apache-lb-ip1"
}

output "lb_external_ip" {
  value = google_compute_global_address.lb_ip.address
}

resource "google_compute_instance" "centos_vm" {
  count        = var.instance_count
  name         = "sekhar-${count.index}"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-stream-9"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }
tags = ["http-server"]
}

output "vm_ips" {
  value = [for instance in google_compute_instance.centos_vm : instance.network_interface[0].access_config[0].nat_ip]
}

variable "instance_count" {
  description = "The number of instances to create."
  type        = number
  default     = 2
}

