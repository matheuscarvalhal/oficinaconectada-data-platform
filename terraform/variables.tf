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

variable "mongo_root_username" {
  type    = string
  default = "mongo_admin"
}

variable "mongo_root_password" {
  type      = string
  sensitive = true
}
