variable "region" {
  type    = string
  default = "sa-east-1"
}

variable "project_name" {
  type    = string
  default = "oficinaconectada"
}

variable "main_db_password" {
  type      = string
  sensitive = true
}

variable "os_db_password" {
  type      = string
  sensitive = true
}

variable "billing_db_password" {
  type      = string
  sensitive = true
}

variable "docdb_master_password" {
  type      = string
  sensitive = true
}
