provider "aws" {
  region = var.region
}

data "terraform_remote_state" "foundation" {
  backend = "s3"

  config = {
    bucket = "oficinaconectada-terraform-state"
    key    = "oficinaconectada-foundation/terraform.tfstate"
    region = var.region
  }
}

locals {
  private_subnets = data.terraform_remote_state.foundation.outputs.private_subnet_ids
  vpc_id          = data.terraform_remote_state.foundation.outputs.vpc_id
  vpc_cidr        = data.terraform_remote_state.foundation.outputs.vpc_cidr

  common_tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
    Layer     = "data-platform"
  }
}

resource "aws_security_group" "data" {
  name   = "${var.project_name}-data-sg"
  vpc_id = local.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  ingress {
    from_port   = 9092
    to_port     = 9098
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    Name = "${var.project_name}-data-sg"
  }, local.common_tags)
}

resource "aws_db_subnet_group" "postgres" {
  name       = "${var.project_name}-postgres-subnet-group"
  subnet_ids = local.private_subnets

  tags = local.common_tags
}

resource "aws_db_instance" "main_app" {
  identifier             = "${var.project_name}-main-app-postgres"
  engine                 = "postgres"
  engine_version         = "15.14"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  max_allocated_storage  = 100
  db_name                = "oficinaconectada"
  username               = "app_user"
  password               = var.main_db_password
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.data.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = false

  tags = local.common_tags
}

resource "aws_db_instance" "os_service" {
  identifier             = "${var.project_name}-os-postgres"
  engine                 = "postgres"
  engine_version         = "15.14"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  max_allocated_storage  = 100
  db_name                = "oficinaconectada_os"
  username               = "os_user"
  password               = var.os_db_password
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.data.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = false

  tags = local.common_tags
}

resource "aws_db_instance" "billing_service" {
  identifier             = "${var.project_name}-billing-postgres"
  engine                 = "postgres"
  engine_version         = "15.14"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  max_allocated_storage  = 100
  db_name                = "oficinaconectada_billing"
  username               = "billing_user"
  password               = var.billing_db_password
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.data.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = false

  tags = local.common_tags
}

resource "aws_docdb_subnet_group" "main" {
  name       = "${var.project_name}-docdb-subnet-group"
  subnet_ids = local.private_subnets

  tags = local.common_tags
}

resource "aws_docdb_cluster" "main" {
  cluster_identifier      = "${var.project_name}-docdb"
  engine                  = "docdb"
  master_username         = "docdb_admin"
  master_password         = var.docdb_master_password
  db_subnet_group_name    = aws_docdb_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.data.id]
  skip_final_snapshot     = true
  backup_retention_period = 1

  tags = local.common_tags
}

resource "aws_docdb_cluster_instance" "main" {
  identifier         = "${var.project_name}-docdb-1"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = "db.t3.medium"

  tags = local.common_tags
}

resource "aws_msk_configuration" "main" {
  kafka_versions = ["3.6.0"]
  name           = "${var.project_name}-msk-config"

  server_properties = <<PROPERTIES
auto.create.topics.enable=true
default.replication.factor=2
min.insync.replicas=1
num.partitions=3
PROPERTIES
}

resource "aws_msk_cluster" "main" {
  cluster_name           = "${var.project_name}-msk"
  kafka_version          = "3.6.0"
  number_of_broker_nodes = 2

  broker_node_group_info {
    instance_type   = "kafka.t3.small"
    client_subnets  = local.private_subnets
    security_groups = [aws_security_group.data.id]

    storage_info {
      ebs_storage_info {
        volume_size = 100
      }
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.main.arn
    revision = aws_msk_configuration.main.latest_revision
  }

  tags = local.common_tags
}
