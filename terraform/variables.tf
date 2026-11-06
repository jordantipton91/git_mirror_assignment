variable "cluster_name" {
  type        = string
  default     = "git-mirror"
  description = "Name of the kind cluster"
}

variable "node_image" {
  type        = string
  default     = "kindest/node:v1.33.1"
  description = "kind node image, which sets the Kubernetes version"
}

variable "namespace" {
  type        = string
  default     = "git-mirror"
  description = "Namespace for the mirror"
}

variable "image_name" {
  type        = string
  default     = "git-mirror"
  description = "Name of the mirror image built from the docker folder"
}

variable "image_tag" {
  type        = string
  default     = "0.1.0"
  description = "Tag of the mirror image. Change it when the Dockerfile changes"
}

variable "source_repo_url" {
  type        = string
  description = "HTTPS URL of the external repository to mirror"
}

variable "source_repo_token" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Read only access token. Leave empty for a public repository"
}

variable "sync_interval_seconds" {
  type        = number
  default     = 30
  description = "Seconds between fetches from the external repository"
}

variable "host_port" {
  type        = number
  default     = 9418
  description = "Port on your machine that forwards to the mirror"
}
