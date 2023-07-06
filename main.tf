# resource "yandex_kms_symmetric_key" "postgres_kms_key" {
#   name              = "postgres-kms-key"
#   default_algorithm = "AES_256"
# }

# resource "yandex_vpc_subnet" "postgres_subnet" {
#   name           = "postgres-subnet"
#   v4_cidr_blocks = ["10.17.0.0/16"]
#   zone           = "ru-central1-a"
#   network_id     = local.network_id
# }

# module "postgres_sg" {
#   source = "./module/security-group"

#   name       = "postgres-sg"
#   network_id = local.network_id
#   security_rules = {
#     ingress = [
#       { target = "self_security_group", from_port = 0, to_port = 65535, proto = "ANY" },
#       { cidr_v4 = yandex_vpc_subnet.postgres_subnet.v4_cidr_blocks, from_port = 0, to_port = 65535, proto = "ANY" },
#       { cidr_v4 = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"], from_port = 0, to_port = 65535, proto = "ICMP" },
#       { cidr_v4 = local.allowed_ip, port = 6432, proto = "TCP" },
#     ]
#   }
# }

# resource "yandex_mdb_postgresql_cluster" "postgres_cluster" {
#   name        = "postgres-db"
#   environment = "PRODUCTION"

#   network_id         = local.network_id
#   security_group_ids = [module.postgres_sg.id]

#   lifecycle {
#     ignore_changes = [
#       host_master_name
#     ]
#   }

#   config {
#     version = local.postgres_version

#     resources {
#       resource_preset_id = "b1.medium"
#       disk_type_id       = "network-ssd"
#       disk_size          = 16
#     }

#     performance_diagnostics {
#       enabled                      = true
#       sessions_sampling_interval   = 10
#       statements_sampling_interval = 60
#     }

#     access {
#       data_lens  = true
#       web_sql    = true
#       serverless = true
#     }

#     postgresql_config = {
#       max_connections                = length(local.postgres_db_list) * 10 + 30
#       enable_parallel_hash           = true
#       autovacuum_vacuum_scale_factor = 0.34
#       default_transaction_isolation  = "TRANSACTION_ISOLATION_READ_COMMITTED"
#       shared_preload_libraries       = "SHARED_PRELOAD_LIBRARIES_AUTO_EXPLAIN,SHARED_PRELOAD_LIBRARIES_PG_HINT_PLAN"
#     }
#   }

#   host {
#     zone             = "ru-central1-a"
#     subnet_id        = yandex_vpc_subnet.postgres_subnet.id
#     assign_public_ip = true
#     name             = "postgres-db-ru-central1-a-1"
#   }

#   # host {
#   #   zone             = "ru-central1-a"
#   #   subnet_id        = yandex_vpc_subnet.postgres_subnet.id
#   #   assign_public_ip = true
#   #   name             = "postgres-db-ru-central1-a-2"
#   # }
# }

# resource "random_password" "postgres_password_admin" {
#   length  = 24
#   special = false
# }

# resource "yandex_mdb_postgresql_user" "postgres_user_admin" {
#   cluster_id = yandex_mdb_postgresql_cluster.postgres_cluster.id
#   name       = "cluster-admin"
#   password   = random_password.postgres_password_admin.result
#   conn_limit = 4

#   grants = ["mdb_admin", "mdb_replication"]
# }

# locals {
#   postgres_db_list_only = [for db in local.postgres_db_list : "${split(":", "${db}")[0]}"]
# }

# resource "random_password" "postgres_password" {
#   for_each = toset(local.postgres_db_list_only)

#   length  = 18
#   special = false
# }

# resource "yandex_mdb_postgresql_user" "postgres_user" {
#   for_each = toset(local.postgres_db_list_only)

#   cluster_id = yandex_mdb_postgresql_cluster.postgres_cluster.id
#   name       = each.key
#   password   = random_password.postgres_password[each.key].result
#   conn_limit = 10
# }

# resource "yandex_mdb_postgresql_database" "postgres_db" {
#   for_each = toset(local.postgres_db_list)

#   cluster_id = yandex_mdb_postgresql_cluster.postgres_cluster.id
#   owner      = split(":", each.value)[0]
#   name       = split(":", each.value)[0]

#   lc_collate = "en_US.UTF-8"
#   lc_type    = "en_US.UTF-8"

#   # pg_trgm btree_gin btree_gist uuid-ossp

#   dynamic "extension" {
#     for_each = toset(slice(split(":", each.value), 1, length(split(":", each.value))))

#     content {
#       name = extension.value
#     }
#   }

#   depends_on = [yandex_mdb_postgresql_user.postgres_user]
# }

# resource "yandex_lockbox_secret" "postgres_lockbox" {
#   name       = "postgres-cluster-dsn"
#   kms_key_id = yandex_kms_symmetric_key.postgres_kms_key.id
# }

# resource "yandex_lockbox_secret_version" "postgres_lockbox_version" {
#   secret_id = yandex_lockbox_secret.postgres_lockbox.id

#   entries {
#     key        = "cluster-admin"
#     text_value = join(",", [for host in yandex_mdb_postgresql_cluster.postgres_cluster.host : "postgres://cluster-admin:${random_password.postgres_password_admin.result}@${host.fqdn}:6432"])
#   }

#   dynamic "entries" {
#     for_each = toset(local.postgres_db_list_only)

#     content {
#       key        = entries.value
#       text_value = join(",", [for host in yandex_mdb_postgresql_cluster.postgres_cluster.host : "postgres://${entries.value}:${random_password.postgres_password[entries.value].result}@${host.fqdn}:6432/${entries.value}"])
#     }
#   }
# }
