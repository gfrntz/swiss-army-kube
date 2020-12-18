data "aws_eks_cluster" "cluster" {
  name = module.kubernetes.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.kubernetes.cluster_name
}



locals {
  environment  = "dev"
  project      = "EDUCATION"
  cluster_name = "swiss-army-grusakov"
  tags = {
    environment = local.environment
    project     = local.project
  }
}

module "network" {
  source = "../../modules/network"

  availability_zones = ["eu-north-1a", "eu-north-1b"]
  environment        = local.environment
  project            = local.project
  cluster_name       = local.cluster_name
  network            = 128
}

module "kubernetes" {
  source = "../../modules/kubernetes"

  environment        = local.environment
  project            = local.project
  availability_zones = ["eu-north-1a", "eu-north-1b"]
  cluster_name       = local.cluster_name
  cluster_version    = "1.18"
  vpc_id             = module.network.vpc_id
  subnets            = module.network.private_subnets
  admin_arns = [
    {
      userarn  = "arn:aws:iam::060183668755:user/grusakov"
      username = "grusakov"
      groups   = ["system:masters"]
    }
  ]
  user_arns = []
  # [
  #  {
  #    userarn  = "arn:aws:iam::720865994912:user/gfrntz"
  #    username = "developer"
  #    groups   = ["system:developers"]
  #  },
  # ]
  #On-demand
  on_demand_common_max_cluster_size = 5
  on_demand_common_min_cluster_size = 2
  on_demand_common_desired_capacity = 2
  on_demand_common_instance_type    = ["m5.large", "m5.xlarge"] # "m5.2xlarge"]

  #Spot
  spot_max_cluster_size = 3
  spot_min_cluster_size = 0
  spot_desired_capacity = 0
  spot_instance_type    = ["m5.large", "m5.xlarge"] #, "m5.2xlarge"]
  #CPU
  on_demand_cpu_max_cluster_size = 0
  on_demand_cpu_min_cluster_size = 0
  on_demand_cpu_desired_capacity = 0
  #GPU
  on_demand_gpu_max_cluster_size = 0
  on_demand_gpu_min_cluster_size = 0
  on_demand_gpu_desired_capacity = 0
  on_demand_gpu_instance_type = ["g4dn.xlarge"]
}
#
module "system" {
  # module_depends_on = [module.network.vpc_id, module.kubernetes.cluster_name, module.kubernetes.workers_launch_template_ids]
  module_depends_on = [module.network.vpc_id, module.kubernetes.cluster_name]
  source            = "../../modules/system"

  environment        = local.environment
  project            = local.project
  cluster_name       = module.kubernetes.cluster_name
  vpc_id             = module.network.vpc_id
  aws_private        = "false"
  domains            = ["swiss-army-grusakov.edu.provectus.io"]
  mainzoneid         = "Z8GDJIR4L7SDX"
  cert_manager_email = "takebsd@gmail.com"
  cluster_oidc_url   = module.kubernetes.cluster_oidc_url
  cluster_oidc_arn   = module.kubernetes.cluster_oidc_arn
  config_path        = "kubeconfig_${local.cluster_name}"
  cluster_roles      = []
}

# module "scaling" {
#   module_depends_on = [module.system.cert-manager]
#   source            = "../../modules/scaling"
#   cluster_name      = module.kubernetes.cluster_name
# }

# module "acm" {
#   source  = "terraform-aws-modules/acm/aws"
#   version = "~> v2.12"
#
#   domain_name               = "swiss-army-grusakov.edu.provectus.io"
#   subject_alternative_names = ["*.swiss-army-grusakov.edu.provectus.io"]
#   zone_id                   = module.system.route53_zone[0].zone_id
#   validate_certificate      = false
#   tags                      = local.tags
# }
# #
module "nginx" {
  module_depends_on = [module.system.cert-manager]
  source            = "../../modules/ingress/nginx"

  cluster_name = module.kubernetes.cluster_name
  aws_private  = "false"
  domains      = ["swiss-army-grusakov.edu.provectus.io"]

  #Need oauth2-proxy github auth? Use id and secret in base64
  github-auth          = "false"
  # github-client-id     = "<github-client-id>"
  # github-org           = "<github-org>"
  # github-client-secret = "<github-client-secret>"
  # cookie-secret        = "<cookie-secret>"

  #Settings for oauth2-proxy google auth
  google-auth          = "false"
  # google-client-id     = "<google-client-id>"
  # google-client-secret = "<google-client-secret>"
  # google-cookie-secret = "<google-cookie-secret>"
}


# loadbalancer controller

# module "alb-ingress" {
#   module_depends_on = [module.system.cert-manager]
#   source            = "../../modules/ingress/alb-ingress"
#   cluster_name      = module.kubernetes.cluster_name
#   domains           = ["swiss-army-grusakov.gfrntz.me"]
#   vpc_id            = module.network.vpc_id
#   aws_region        = "eu-north-1"
#   certificates_arns = [module.acm.this_acm_certificate_arn]
#   cluster_oidc_url  = module.kubernetes.cluster_oidc_url
# }

module "argo" {
  module_depends_on = [module.system.cluster_available]
  source            = "../../modules/cicd/argo"
  cluster_name      = module.kubernetes.cluster_name
  domains           = ["swiss-army-grusakov.edu.provectus.io"]
  environment       = local.environment
  project           = local.project
  cluster_oidc_url  = module.kubernetes.cluster_oidc_url
}

## Use EKS 1.15 if you want to deploy Kubeflow !!!
#module "kubeflow" {
#  module_depends_on = [module.system.cert-manager, module.argo]
#  source            = "../../modules/kubeflow"
#  vpc               = module.network.vpc
#  cluster_name      = module.kubernetes.cluster_name
#  cluster           = module.kubernetes.this
#  artifacts         = module.argo.artifacts
#}

# module "efs" {
#  module_depends_on = [module.system.cert-manager]
#  source            = "../../modules/storage/efs"
#  vpc               = module.network.vpc
#  cluster_name      = module.kubernetes.cluster_name
# }

# module "jenkins" {
#   module_depends_on = [module.system.cert-manager, module.nginx.nginx-ingress]
#   source            = "../../modules/cicd/jenkins"

#   domains          = ["swiss-army.example.io"]
#   jenkins_password = "<jenkins_password>"

#   environment      = local.environment
#   project          = local.project
#   cluster_name     = module.kubernetes.cluster_name
#   cluster_oidc_url = module.kubernetes.cluster_oidc_url
#   cluster_oidc_arn = module.system.oidc_arn

#   master_policy = "<master_policy>"
#   agent_policy  = "<agent_policy>"
# }

module "prometheus" {
 module_depends_on                 = [module.system.cert-manager, module.nginx.nginx-ingress]
 source                            = "../../modules/monitoring/prometheus"

 cluster_name                      = module.kubernetes.cluster_name
 domains                           = ["swiss-army-grusakov.edu.provectus.io"]
 grafana_google_auth               = "false"
 # grafana_client_id               = "<grafana_client_id>"
 # grafana_client_secret           = "<grafana_client_secret>"
 # grafana_allowed_domains         = "<grafana_allowed_domains>"
 prometheus_disable_rule_selectors = true
 victoria_metrics_enabled          = true
}

module "loki" {
 module_depends_on = [module.system.cert-manager,module.nginx.nginx-ingress]
 source            = "../../modules/logging/loki"

 cluster_name = module.kubernetes.cluster_name
 domains      = ["swiss-army-grusakov.edu.provectus.io"]
}

# module "efk" {
#  module_depends_on     = [module.system.cert-manager,module.nginx.nginx-ingress]
#  source                = "../../modules/logging/efk"
#  domains               = ["swiss-army.example.io"]
#  elasticsearch-curator = "<elasticsearch-curator>"
#  logstash              = "<logstash>"
#  filebeat              = "<filebeat>"
#  success_limit         = "<success_limit>"
#  failed_limit          = "<failed_limit>"
#  elasticDataSize       = "<elasticDataSize>"
#  efk_oauth2_domain     = "<efk_oauth2_domain>"
# }

# module "rds" {
#  module_depends_on = [module.network.vpc_id, module.kubernetes.cluster_name, module.kubernetes.workers_launch_template_ids]
#  source            = "../../modules/rds"

#  environment  = local.environment
#  project      = local.project
#  cluster_name = module.kubernetes.cluster_name
#  subnets                             = module.network.private_subnets
#  rds_database_name                   = "<rds_database_name>"
#  rds_database_username               = "<rds_database_username>"
#  rds_database_password               = "<rds_database_password>"
#  rds_database_engine                 = "<rds_database_engine>"
#  rds_database_engine_version         = "<rds_database_engine_version>"
#  rds_database_major_engine_version   = "<rds_database_major_engine_version>"
#  rds_database_instance               = "<rds_database_instance>"
#  rds_database_multi_az               = "<rds_database_multi_az>"
#  rds_database_delete_protection      = "<rds_database_delete_protection>"
#  rds_allocated_storage               = "<rds_allocated_storage>"
#  rds_storage_encrypted               = "<rds_storage_encrypted>"
#  rds_kms_key_id                      = "<rds_kms_key_id>"
#  rds_maintenance_window              = "<rds_maintenance_window>"
#  rds_backup_window                   = "<rds_backup_window>"
#  rds_database_tags                   = "<rds_database_tags>"
#  vpc_id                              = module.network.vpc_id
# }

# module "airflow" {
#  module_depends_on = [module.system.cert-manager, module.nginx.nginx-ingress]
#  source            = "../../modules/airflow"
#
#  cluster_name                = module.kubernetes.cluster_name
#  domains                     = ["swiss-army.example.io"]
#  airflow_password            = "<airflow_password>"
#  airflow_username            = "<airflow_username>"
#  airflow_fernetKey           = "<airflow_fernetKey>"
#  airflow_postgresql_local    = "<airflow_postgresql_local>"
#  airflow_postgresql_host     = "<airflow_postgresql_host>"
#  airflow_postgresql_port     = "<airflow_postgresql_port>"
#  airflow_postgresql_username = "<airflow_postgresql_username>"
#  airflow_postgresql_password = "<airflow_postgresql_password>"
#  airflow_postgresql_database = "<airflow_postgresql_database>"
#  airflow_redis_local         = "<airflow_redis_local>"
#  airflow_redis_host          = "<airflow_redis_host>"
#  airflow_redis_port          = "<airflow_redis_port>"
#  airflow_redis_username      = "<airflow_redis_username>"
#  airflow_redis_password      = "<airflow_redis_password>"
# }
