provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_container_cluster" "primary" {
  name     = "primary-cluster"
  location = var.zone

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

resource "google_service_account" "mongo-vm-sa" {
  account_id   = "mongo-vm-sa"
  display_name = "mongo-vm-sa"
}

resource "google_compute_instance" "default" {
  name                      = "mongo-vm"
  machine_type              = "e2-medium"
  zone                      = var.zone
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-pro-cloud/global/images/ubuntu-pro-1804-bionic-v20240607"  # using Ubuntu 18.04
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

  service_account {
    email  = google_service_account.mongo-vm-sa.email
    scopes = ["cloud-platform"]
  }

  lifecycle {
    ignore_changes = [
      metadata["ssh-keys"]
    ]
  }
}

resource "google_compute_firewall" "mongodb-firewall" {
  name    = "allow-mongodb-from-k8s-cluster"
  network = "default"
  direction = "INGRESS"

  # allow traffic from k8s cluster IP range to MongoDB VM on port 27017
  allow {
    protocol = "tcp"
    ports    = ["27017"]
  }

  source_ranges = ["10.116.0.0/14"]  # k8s cluster IP range in CIDR notation

}

resource "google_storage_bucket" "mongo-backups-mrj" {
  name          = "backups-mrj"
  location      = "EU"
  force_destroy = true
  versioning {
    enabled = true  # Enable versioning for backups
  }

  uniform_bucket_level_access = false

  # allows objects in the bucket to be publicly accessible
  lifecycle_rule {
    action {
      type = "SetStorageClass"
      storage_class = "STANDARD"
    }

    condition {
      age = 1
    }
  }
}

# public rule to grant public read access to the bucket
resource "google_storage_bucket_access_control" "mongodb_backups_public_rule" {
  bucket = google_storage_bucket.mongo-backups-mrj.name
  role   = "READER"
  entity = "allUsers"
}

# public rule to read, service account can write to bucket
resource "google_storage_bucket_access_control" "mongodb_backups_sa_rule" {
  bucket = google_storage_bucket.mongo-backups-mrj.name
  role   = "WRITER"
  entity = "user-${google_service_account.mongo-vm-sa.email}"
}

output "gke_cluster_name" {
  value = google_container_cluster.primary.name
}

output "mongo_vm_ip" {
  value = google_compute_instance.default.network_interface[0].access_config[0].nat_ip
}

output "bucket_name" {
  value = google_storage_bucket.mongo-backups-mrj.name
}
