locals {
  service_account_key_file        = "${path.module}/${var.service_account_key_file}"
  service_account_static_key_file = "${path.module}/${var.service_account_static_key_file}"
  config_file                     = "${path.module}/${var.config_file}"
}

data "external" "sa_json" {
  program = [
    "jq",
    "-f",
    "${local.service_account_static_key_file}"
  ]
}

data "external" "config_json" {
  program = [
    "jq",
    "-f",
    "${local.config_file}"
  ]
}

data "http" "ip" {
  url = "https://ipv4.icanhazip.com"
}

locals {
  ip      = chomp(data.http.ip.response_body)
  ip_cidr = "${chomp(data.http.ip.response_body)}/32"
}

locals {
  postgres_version = data.external.config_json.result.postgres_version
  postgres_db_list = split(",", data.external.config_json.result.postgres_db_list)
}

locals {
  provider_endpoint = data.external.sa_json.result.provider_endpoint
  storage_endpoint  = data.external.sa_json.result.storage_endpoint

  sa_access_key = data.external.sa_json.result.static_access_key
  sa_secret_key = data.external.sa_json.result.static_secret_key

  cloud_id   = data.external.config_json.result.cloud_id
  folder_id  = data.external.config_json.result.folder_id
  network_id = data.external.config_json.result.network_id
  allowed_ip = data.external.config_json.result.allowed_ip
}

