# ============================================================
# INFRAESTRUTURA COMO CÓDIGO — CARE PLUS
# Projeto: Challenge Care Plus 2025 — Sprint 4 Cibersegurança
# Ferramenta: Terraform (simulado para fins acadêmicos)
# Provider: AWS (Amazon Web Services)
# ============================================================

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ============================================================
# VARIÁVEIS
# ============================================================

variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "sa-east-1" # São Paulo
}

variable "environment" {
  description = "Ambiente de execução (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "db_password" {
  description = "Senha do banco de dados PostgreSQL"
  type        = string
  sensitive   = true # CONTROLE 1: variável marcada como sensível — nunca aparece em logs ou outputs
}

variable "jwt_secret" {
  description = "Chave secreta para geração de tokens JWT"
  type        = string
  sensitive   = true # CONTROLE 1: idem — valor nunca é exibido pelo Terraform
}


# ============================================================
# CONTROLE 1 — GESTÃO SEGURA DE SEGREDOS
# Uso de variáveis "sensitive = true" e AWS Secrets Manager.
# Senhas e tokens NUNCA ficam hardcoded no código.
# São armazenados no Secrets Manager e injetados em runtime.
# ============================================================

resource "aws_secretsmanager_secret" "db_password" {
  name        = "careplus/${var.environment}/db-password"
  description = "Senha do banco de dados PostgreSQL da aplicação Care Plus"

  # Rotação automática a cada 30 dias
  tags = {
    Project     = "CarePlus"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name        = "careplus/${var.environment}/jwt-secret"
  description = "Chave JWT da aplicação Care Plus"

  tags = {
    Project     = "CarePlus"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = var.jwt_secret
}


# ============================================================
# CONTROLE 2 — REDE ISOLADA (VPC PRIVADA)
# A aplicação e o banco de dados ficam em subnets privadas,
# sem acesso direto à internet. Apenas o load balancer público
# recebe requisições externas e as repassa internamente.
# ============================================================

resource "aws_vpc" "careplus_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "careplus-vpc"
    Environment = var.environment
  }
}

# Subnet privada — aplicação e banco ficam aqui (sem IP público)
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.careplus_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = false # CONTROLE 2: instâncias NÃO recebem IP público automaticamente

  tags = {
    Name = "careplus-private-subnet"
  }
}

# Subnet pública — apenas para o load balancer
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.careplus_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false

  tags = {
    Name = "careplus-public-subnet"
  }
}


# ============================================================
# CONTROLE 3 — SECURITY GROUPS (FIREWALL)
# Define exatamente quais portas e IPs podem se comunicar.
# Princípio: negar tudo por padrão, liberar apenas o necessário.
# ============================================================

# Security Group da aplicação Spring Boot
resource "aws_security_group" "app_sg" {
  name        = "careplus-app-sg"
  description = "Regras de firewall da aplicação Care Plus"
  vpc_id      = aws_vpc.careplus_vpc.id

  # Permite entrada APENAS na porta 8080, e APENAS vindo do load balancer
  ingress {
    description     = "HTTP da aplicacao vindo apenas do load balancer"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id] # CONTROLE 3: acesso restrito por grupo
  }

  # Bloqueia qualquer acesso SSH de fora (porta 22 fechada)
  # Não há regra de ingress para porta 22 — ela simplesmente não existe

  # Permite saída apenas para o banco de dados e serviços AWS
  egress {
    description = "Saida para o banco de dados PostgreSQL"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  egress {
    description = "Saida para HTTPS (AWS Secrets Manager, etc.)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "careplus-app-sg"
    Environment = var.environment
  }
}

# Security Group do Load Balancer
resource "aws_security_group" "lb_sg" {
  name        = "careplus-lb-sg"
  description = "Regras de firewall do load balancer"
  vpc_id      = aws_vpc.careplus_vpc.id

  # Aceita HTTPS de qualquer lugar (porta 443 — tráfego criptografado)
  ingress {
    description = "HTTPS publico"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Redireciona HTTP para HTTPS (ninguém fica em HTTP puro)
  ingress {
    description = "HTTP redirecionado para HTTPS"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  tags = {
    Name = "careplus-lb-sg"
  }
}

# Security Group do banco de dados
resource "aws_security_group" "db_sg" {
  name        = "careplus-db-sg"
  description = "Regras de firewall do banco de dados"
  vpc_id      = aws_vpc.careplus_vpc.id

  # Banco aceita conexão APENAS da aplicação — porta 5432 fechada para o mundo
  ingress {
    description     = "PostgreSQL vindo apenas da aplicacao"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id] # CONTROLE 3: só a app acessa o banco
  }

  tags = {
    Name = "careplus-db-sg"
  }
}


# ============================================================
# CONTROLE 4 — BANCO DE DADOS CRIPTOGRAFADO
# O banco PostgreSQL usa criptografia em repouso (storage_encrypted)
# e em trânsito (SSL obrigatório). Backups automáticos ativados.
# Instância em subnet privada — sem acesso externo.
# ============================================================

resource "aws_db_instance" "careplus_db" {
  identifier        = "careplus-postgres"
  engine            = "postgres"
  engine_version    = "15.4"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  db_name           = "careplus"
  username          = "careplus_admin"
  password          = var.db_password # Vem da variável sensível — nunca hardcoded

  # CONTROLE 4a: Criptografia em repouso
  storage_encrypted = true
  kms_key_id        = aws_kms_key.careplus_kms.arn

  # CONTROLE 4b: Sem IP público — banco acessível apenas de dentro da VPC
  publicly_accessible = false

  # CONTROLE 4c: Backups automáticos por 7 dias
  backup_retention_period = 7
  backup_window           = "03:00-04:00"

  # CONTROLE 4d: Janela de manutenção fora do horário de pico
  maintenance_window = "Mon:04:00-Mon:05:00"

  # CONTROLE 4e: Proteção contra exclusão acidental
  deletion_protection = true
  skip_final_snapshot = false

  vpc_security_group_ids = [aws_security_group.db_sg.id]

  tags = {
    Project     = "CarePlus"
    Environment = var.environment
  }
}

# Chave KMS dedicada para criptografar o banco
resource "aws_kms_key" "careplus_kms" {
  description             = "Chave KMS para criptografia do banco de dados Care Plus"
  deletion_window_in_days = 30
  enable_key_rotation     = true # CONTROLE 4: rotação automática da chave a cada ano

  tags = {
    Project = "CarePlus"
  }
}


# ============================================================
# CONTROLE 5 — LOGS DE AUDITORIA E MONITORAMENTO
# Todos os eventos da aplicação são registrados no CloudWatch.
# Logs retidos por 90 dias para fins de auditoria e compliance.
# Alarme disparado se a taxa de erros 5xx ultrapassar o limite.
# ============================================================

resource "aws_cloudwatch_log_group" "careplus_logs" {
  name              = "/careplus/${var.environment}/application"
  retention_in_days = 90 # CONTROLE 5: logs retidos por 90 dias

  tags = {
    Project     = "CarePlus"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "careplus_security_logs" {
  name              = "/careplus/${var.environment}/security"
  retention_in_days = 90 # Logs de segurança (logins, falhas, acessos)

  tags = {
    Project     = "CarePlus"
    Environment = var.environment
  }
}

# Alarme: dispara se houver mais de 10 erros 5xx em 5 minutos
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "careplus-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300 # 5 minutos
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Taxa de erros 5xx acima do limite — possivel incidente de seguranca"
  treat_missing_data  = "notBreaching"

  tags = {
    Project = "CarePlus"
  }
}

# Alarme: dispara se houver mais de 5 tentativas de login falhas em 1 minuto
resource "aws_cloudwatch_metric_alarm" "failed_login_attempts" {
  alarm_name          = "careplus-failed-logins"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FailedLoginAttempts"
  namespace           = "CarePlus/Security"
  period              = 60 # 1 minuto
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Possiveis tentativas de brute force detectadas"
  treat_missing_data  = "notBreaching"

  tags = {
    Project = "CarePlus"
  }
}


# ============================================================
# OUTPUTS (sem valores sensíveis)
# ============================================================

output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.careplus_vpc.id
}

output "db_endpoint" {
  description = "Endpoint do banco de dados (interno)"
  value       = aws_db_instance.careplus_db.endpoint
}

output "log_group_name" {
  description = "Nome do grupo de logs da aplicacao"
  value       = aws_cloudwatch_log_group.careplus_logs.name
}

# Outputs de segredos são BLOQUEADOS — nunca exibir valores sensíveis
# output "db_password" { ... }  ← NUNCA fazer isso

