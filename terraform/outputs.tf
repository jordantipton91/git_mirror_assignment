output "kubeconfig" {
  description = "Path to the kubeconfig file for the cluster"
  value       = kind_cluster.this.kubeconfig_path
}

output "clone_url_local" {
  description = "Clone URL from your machine"
  value       = "git://localhost:${var.host_port}/repo.git"
}

output "clone_url_in_cluster" {
  description = "Clone URL from pods inside the cluster"
  value       = "git://${local.release}.${var.namespace}.svc.cluster.local:${local.git_port}/repo.git"
}
