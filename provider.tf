terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.89.0"
    }
  }
  backend "s3" {
    region = "us-east-1"

    skip_metadata_api_check     = true
    skip_credentials_validation = true
  }
  required_version = ">= 1.3.0"
}

provider "yandex" {
  cloud_id  = local.cloud_id
  folder_id = local.folder_id

  endpoint         = local.provider_endpoint
  storage_endpoint = local.storage_endpoint

  service_account_key_file = local.service_account_key_file
  storage_access_key       = local.sa_access_key
  storage_secret_key       = local.sa_secret_key
}
