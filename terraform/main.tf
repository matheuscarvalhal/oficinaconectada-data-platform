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
  primary_subnet  = local.private_subnets[0]

  common_tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
    Layer     = "data-platform"
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
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

resource "aws_instance" "main_app_postgres" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = local.primary_subnet
  vpc_security_group_ids      = [aws_security_group.data.id]
  associate_public_ip_address = false

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data_replace_on_change = true
  user_data = <<-EOF
              #!/bin/bash
              set -eux
              dnf update -y
              dnf install -y docker
              systemctl enable --now docker
              docker volume create postgres_main_data
              docker run -d \
                --name postgres-main \
                --restart unless-stopped \
                -p 5432:5432 \
                -e POSTGRES_DB=oficinaconectada \
                -e POSTGRES_USER=app_user \
                -e POSTGRES_PASSWORD=${var.main_db_password} \
                -v postgres_main_data:/var/lib/postgresql/data \
                postgres:15
              EOF

  tags = merge({
    Name = "${var.project_name}-main-postgres-ec2"
  }, local.common_tags)
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

resource "aws_instance" "mongo" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = local.primary_subnet
  vpc_security_group_ids      = [aws_security_group.data.id]
  associate_public_ip_address = false

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data_replace_on_change = true
  user_data = <<-EOF
              #!/bin/bash
              set -eux
              dnf update -y
              dnf install -y docker
              systemctl enable --now docker
              docker volume create mongodb_data
              docker run -d \
                --name mongodb \
                --restart unless-stopped \
                -p 27017:27017 \
                -e MONGO_INITDB_ROOT_USERNAME=${var.mongo_root_username} \
                -e MONGO_INITDB_ROOT_PASSWORD=${var.mongo_root_password} \
                -v mongodb_data:/data/db \
                mongo:7
              EOF

  tags = merge({
    Name = "${var.project_name}-mongo-ec2"
  }, local.common_tags)
}

resource "aws_instance" "kafka" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = local.primary_subnet
  vpc_security_group_ids      = [aws_security_group.data.id]
  associate_public_ip_address = false

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data_replace_on_change = true
  user_data = <<-EOF
              #!/bin/bash
              set -eux
              TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
              PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
              dnf update -y
              dnf install -y docker
              systemctl enable --now docker
              docker run -d \
                --name kafka \
                --restart unless-stopped \
                -p 9092:9092 \
                -e KAFKA_CFG_NODE_ID=1 \
                -e KAFKA_CFG_PROCESS_ROLES=broker,controller \
                -e KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER \
                -e KAFKA_CFG_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093 \
                -e KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://$PRIVATE_IP:9092 \
                -e KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT \
                -e KAFKA_CFG_INTER_BROKER_LISTENER_NAME=PLAINTEXT \
                -e KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=1@$PRIVATE_IP:9093 \
                -e KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE=true \
                -e KAFKA_CFG_NUM_PARTITIONS=3 \
                -e KAFKA_CFG_DEFAULT_REPLICATION_FACTOR=1 \
                -e KAFKA_CFG_OFFSETS_TOPIC_REPLICATION_FACTOR=1 \
                -e KAFKA_CFG_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=1 \
                -e KAFKA_CFG_TRANSACTION_STATE_LOG_MIN_ISR=1 \
                -e KAFKA_KRAFT_CLUSTER_ID=abcdefghijklmnopqrstuv \
                -e ALLOW_PLAINTEXT_LISTENER=yes \
                bitnami/kafka:3.6
              EOF

  tags = merge({
    Name = "${var.project_name}-kafka-ec2"
  }, local.common_tags)
}
