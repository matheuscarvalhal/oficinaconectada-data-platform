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

output "mongo_endpoint" {
  value = aws_instance.mongo.private_dns
}

output "mongo_port" {
  value = 27017
}

output "mongo_root_username" {
  value = var.mongo_root_username
}

output "kafka_bootstrap_servers" {
  value = "${aws_instance.kafka.private_dns}:9092"
}

output "data_security_group_id" {
  value = aws_security_group.data.id
}
