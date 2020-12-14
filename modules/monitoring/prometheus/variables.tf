# For depends_on queqe
variable module_depends_on {
  default     = []
  type        = list(any)
  description = "A list of explicit dependencies"
}

variable cluster_name {
  type        = string
  default     = null
  description = "A name of the Amazon EKS cluster"
}

variable "config_path" {
  description = "location of the kubeconfig file"
  default     = "~/.kube/config"
}

variable "domains" {
  type        = list(string)
  default     = []
  description = "A list of domains to use for ingresses"
}

#Grafana
variable "grafana_password" {
  description = "Password for grafana admin"
  default     = "password"
}

variable "grafana_google_auth" {
  description = "Enables Google auth for Grafana"
  default     = false
}

variable "grafana_client_id" {
  description = "The id of the client for Grafana Google auth"
  default     = ""
}

variable "grafana_client_secret" {
  description = "The token of the client for Grafana Google auth"
  default     = ""
}

variable "grafana_allowed_domains" {
  description = "Allowed domain for Grafana Google auth"
  default     = "local"
}

variable "grafana_version" {
  description = "Grafana version"
  default = "7.3.5"
}

variable "chart_url" {
  description = "Helm charts repo url"
  default     = "https://prometheus-community.github.io/helm-charts"
}

variable "chart_name" {
  description = "Helm chart name"
  default = "kube-prometheus-stack"
}

variable "chart_version" {
  description = "Helm chart version"
  default = "12.8.0"
}

variable "release_name" {
  description = "Release name"
  default     = "kube-prometheus-stack"
}
