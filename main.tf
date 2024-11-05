terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.22.0"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "docker-desktop"  // Replace with your actual context name
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "docker-desktop"  // Replace with your actual context name
  }
}

resource "random_password" "redis_password" {
  length  = 16
  special = false
}

resource "random_password" "mongo_password" {
  length  = 16
  special = false
}

locals {
  mongo_url = format(
    "mongodb://root:%s@tyk-mongo-mongodb.tyk-cp.svc.cluster.local:27017/tyk_analytics?authSource=admin",
    random_password.mongo_password.result
  )
}

resource "kubernetes_namespace" "tyk_cp" {
  metadata {
    name = "tyk-cp"
  }
}

resource "kubernetes_namespace" "tyk_dp" {
  metadata {
    name = "tyk-dp"
  }
}

resource "helm_release" "mongo" {
  name             = "tyk-mongo"
  repository       = "https://marketplace.azurecr.io/helm/v1/repo"
  chart            = "mongodb"
  version          = "10.0.5"
  namespace        = kubernetes_namespace.tyk_cp.metadata[0].name
  create_namespace = false

  set {
    name  = "replicaSet.enabled"
    value = "true"
  }

  set {
    name  = "auth.rootPassword"
    value = random_password.mongo_password.result
  }
}

resource "helm_release" "redis" {
  name             = "tyk-redis-data"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "redis"
  version          = "19.0.2"
  namespace        = "tyk-cp"
  create_namespace = false

  set {
    name  = "auth.password"
    value = random_password.redis_password.result
  }
}

resource "helm_release" "redis_dp" {
  name             = "tyk-redis-dp"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "redis"
  version          = "19.0.2"
  namespace        = kubernetes_namespace.tyk_dp.metadata[0].name
  create_namespace = false

  set {
    name  = "auth.password"
    value = random_password.redis_password.result
  }
}

resource "helm_release" "tyk" {
  name             = "tyk-cp"
  repository       = "https://helm.tyk.io/public/helm/charts"
  chart            = "tyk-control-plane"
  namespace        = "tyk-cp"
  create_namespace = false
  values           = [file("Control-Plane/values.yaml")]

  set {
    name  = "global.redis.pass"
    value = random_password.redis_password.result
  }

  set {
    name  = "global.mongo.mongoURL"
    value = local.mongo_url
  }

  depends_on = [
    helm_release.mongo,
    helm_release.redis,
  ]
}

data "kubernetes_secret" "tyk_operator_conf" {
  metadata {
    name      = "tyk-operator-conf"
    namespace = "tyk-cp"
  }

  depends_on = [
    helm_release.tyk,
  ]
}

resource "helm_release" "tyk_dp" {
  name             = "tyk-data-plane"
  repository       = "https://helm.tyk.io/public/helm/charts"
  chart            = "tyk-data-plane"
  namespace        = "tyk-dp"
  create_namespace = false
  values           = [file("Data-Plane/values.yaml")]

  set {
    name  = "global.redis.pass"
    value = random_password.redis_password.result
  }


  set {
    name  = "global.remoteControlPlane.orgId"
    value = data.kubernetes_secret.tyk_operator_conf.data["TYK_ORG"]
  }

  set {
    name  = "global.remoteControlPlane.userApiKey"
    value = data.kubernetes_secret.tyk_operator_conf.data["TYK_AUTH"]
  }

  depends_on = [
    helm_release.tyk,
    helm_release.redis_dp,
  ]
}

resource "kubernetes_service" "dashboard_nodeport" {
  metadata {
    labels = {
      app = "dashboard-svc-tyk-cp-tyk-dashboard"
    }
    name      = "dashboard-svc-tyk-cp-tyk-dashboard-nodeport"
    namespace = "tyk-cp"
  }

  spec {
    type = "NodePort"

    selector = {
      app = "dashboard-tyk-cp-tyk-dashboard"
    }

    port {
      port        = 3000
      target_port = 3000
    }
  }

  depends_on = [
    helm_release.tyk,
  ]
}

resource "kubernetes_service" "cp_gateway_nodeport" {
  metadata {
    labels = {
      app = "gateway-svc-tyk-cp-tyk-gateway"
    }
    name      = "gateway-svc-tyk-cp-tyk-gateway-nodeport"
    namespace = "tyk-cp"
  }

  spec {
    type = "NodePort"

    selector = {
      app = "gateway-tyk-cp-tyk-gateway"
    }

    port {
      port        = 8080
      target_port = 8080
    }
  }

  depends_on = [
    helm_release.tyk,
  ]
}

resource "kubernetes_service" "dp_gateway_nodeport" {
  metadata {
    labels = {
      app = "gateway-tyk-data-plane-tyk-gateway"
    }
    name      = "gateway-tyk-data-plane-tyk-gateway-nodeport"
    namespace = "tyk-dp"
  }

  spec {
    type = "NodePort"

    selector = {
      app = "gateway-tyk-data-plane-tyk-gateway"
    }

    port {
      port        = 8080
      target_port = 8080
    }
  }

  depends_on = [
    helm_release.tyk_dp,
  ]
}

output "dashboard_nodeport_url" {
  value       = "http://localhost:${kubernetes_service.dashboard_nodeport.spec.0.port.0.node_port}"
  description = "The accessible URL for the Tyk dashboard service."
}

output "ControlPlane_Gateway_URL" {
  value       = "http://localhost:${kubernetes_service.cp_gateway_nodeport.spec.0.port.0.node_port}/hello"
  description = "The accessible URL for the Tyk gateway service."
}

output "DataPlane_Gateway_URL" {
  value       = "http://localhost:${kubernetes_service.dp_gateway_nodeport.spec.0.port.0.node_port}/hello"
  description = "The accessible URL for the Tyk gateway service."
}
