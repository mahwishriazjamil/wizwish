variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "europe-west2"
}

variable "zone" {
  description = "The GCP zone"
  type        = string
  default     = "europe-west2-a"
}
