output "main_db_endpoint" {
  value = aws_db_instance.main_app.address
}

output "main_db_port" {
  value = aws_db_instance.main_app.port
}

output "os_db_endpoint" {
  value = aws_db_instance.os_service.address
}

output "os_db_port" {
  value = aws_db_instance.os_service.port
}

output "billing_db_endpoint" {
  value = aws_db_instance.billing_service.address
}

output "billing_db_port" {
  value = aws_db_instance.billing_service.port
}

output "docdb_endpoint" {
  value = aws_docdb_cluster.main.endpoint
}

output "docdb_port" {
  value = aws_docdb_cluster.main.port
}

output "msk_bootstrap_brokers" {
  value = aws_msk_cluster.main.bootstrap_brokers
}

output "data_security_group_id" {
  value = aws_security_group.data.id
}
