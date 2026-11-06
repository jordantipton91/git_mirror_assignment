locals {
  release    = "git-mirror"
  git_port   = 9418
  node_port  = 30418
  image      = "${var.image_name}:${var.image_tag}"
  docker_dir = abspath("${path.module}/../docker")
  chart_dir  = abspath("${path.module}/../charts/git-mirror")
}

resource "kind_cluster" "this" {
  name            = var.cluster_name
  node_image      = var.node_image
  wait_for_ready  = true
  kubeconfig_path = abspath("${path.module}/${var.cluster_name}.kubeconfig")

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      extra_port_mappings {
        container_port = local.node_port
        host_port      = var.host_port
        listen_address = "127.0.0.1"
      }
    }
  }
}

resource "terraform_data" "image" {
  triggers_replace = [
    kind_cluster.this.id,
    local.image,
    filesha256("${local.docker_dir}/Dockerfile"),
  ]

  provisioner "local-exec" {
    command = "docker build -t ${local.image} ${local.docker_dir} && kind load docker-image ${local.image} --name ${var.cluster_name}"
  }
}

resource "helm_release" "git_mirror" {
  name             = local.release
  namespace        = var.namespace
  create_namespace = true
  chart            = local.chart_dir
  wait             = true
  timeout          = 1200

  values = [yamlencode({
    image = {
      repository = var.image_name
      tag        = var.image_tag
      pullPolicy = "Never"
    }
    source = {
      url = var.source_repo_url
    }
    syncIntervalSeconds = var.sync_interval_seconds
    service = {
      type     = "NodePort"
      nodePort = local.node_port
    }
  })]

  set_sensitive = [{
    name  = "source.token"
    value = var.source_repo_token
  }]

  depends_on = [terraform_data.image]
}
