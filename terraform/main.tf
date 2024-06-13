provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_container_cluster" "primary" {
  name     = "primary-cluster"
  location = var.region

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/trace.append",
    ]
  }

  initial_node_count = 3
}

resource "google_compute_instance" "default" {
  name         = "mongo-vm"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-1804-bionic-v20210609"  # Using Ubuntu 18.04
    }
  }

  network_interface {
    network = "default"
    access_config {
    }
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    wget -qO - https://www.mongodb.org/static/pgp/server-4.2.asc | sudo apt-key add -
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.2.list
    sudo apt-get update
    sudo apt-get install -y mongodb-org=4.2.0
    sudo systemctl start mongod
    sudo systemctl enable mongod
    mongo --eval 'db.createUser({user: "admin", pwd: "password", roles:[{role:"root",db:"admin"}]});'
  EOF
}

resource "google_storage_bucket" "bucket" {
  name          = "mongo-backups-bucket"
  location      = "eu"
  force_destroy = true
}

output "gke_cluster_name" {
  value = google_container_cluster.primary.name
}

output "mongo_vm_ip" {
  value = google_compute_instance.default.network_interface[0].access_config[0].nat_ip
}

output "bucket_name" {
  value = google_storage_bucket.bucket.name
}
