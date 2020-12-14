# Create namespace monitoring
resource "kubernetes_namespace" "monitoring" {
  depends_on = [
    var.module_depends_on
  ]
  metadata {
    name = "monitoring"
  }
}

resource "random_password" "grafana_password" {
  length           = 16
  special          = true
  override_special = "!#%&*()-_=+[]{}<>:?"
}

resource "aws_ssm_parameter" "grafana_password" {
  name  = "/grafana/${var.cluster_name}/admin"
  type  = "SecureString"
  value = random_password.grafana_password.result
}

resource "helm_release" "victoria_metrics_cluster" {
  count       = var.victoria_metrics_enabled ? 1 : 0
  depends_on = [
    var.module_depends_on
  ]
  name         = var.victoria_metrics_release_name
  repository   = var.victoria_metrics_chart_url
  chart        = var.victoria_metrics_chart_name
  version      = var.victoria_metrics_chart_version
  namespace    = kubernetes_namespace.monitoring.metadata[0].name
  recreate_pods = true
  timeout       = 1200

}

resource "helm_release" "monitoring" {
  depends_on = [
    var.module_depends_on
  ]
  name          = var.prometheus_release_name
  repository    = var.prometheus_chart_url
  chart         = var.prometheus_chart_name
  version       = var.prometheus_chart_version
  namespace     = kubernetes_namespace.monitoring.metadata[0].name
  recreate_pods = true
  timeout       = 1200


  values = [templatefile("${path.module}/values/prometheus.yaml",
    {
      alertmanager_enabled         = true
      alertmanager_ingress_enabled = false
      alertmanager_host            = "alertmanager.${var.domains[0]}"
      certmanager_issuer           = "letsencrypt-prod"
      grafana_enabled              = true
      grafana_version              = var.grafana_version
      grafana_pvc_enabled          = true
      grafana_ingress_enabled      = true
      grafana_admin_password       = random_password.grafana_password.result
      grafana_url                  = "grafana.${var.domains[0]}"
      grafana_google_auth          = var.grafana_google_auth
      grafana_allowed_domains      = var.grafana_allowed_domains
      prometheus_enabled           = true
      prometheus_ingress_enabled   = false
      prometheus_url               = "prometheus.${var.domains[0]}"
      victoria_metrics_enabled     = var.victoria_metrics_enabled
    })
  ]
}

resource "kubernetes_secret" "grafana_auth" {
  depends_on = [
    var.module_depends_on
  ]

  count = var.grafana_google_auth == true ? 1 : 0

  metadata {
    name      = "grafana-auth"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    GF_AUTH_GOOGLE_CLIENT_ID     = var.grafana_client_id
    GF_AUTH_GOOGLE_CLIENT_SECRET = var.grafana_client_secret
  }
}
