# ============================================================
# PLANO DE MONITORAMENTO, AUDITORIA E RESPOSTA A INCIDENTES
# Projeto: Challenge Care Plus 2025 — Sprint 4 Cibersegurança
# Serviço: Check-in de Saúde Mental e Estresse
# ============================================================


# ============================================================
# 1. EVENTOS QUE DEVEM SER MONITORADOS
# ============================================================

## 1.1 Autenticação e Controle de Acesso
| Evento                                  | Severidade | Log Group                        |
|-----------------------------------------|------------|----------------------------------|
| Login bem-sucedido                      | INFO       | /careplus/prod/security          |
| Falha de login (senha incorreta)        | WARNING    | /careplus/prod/security          |
| 5+ falhas de login seguidas (bruteforce)| CRITICAL   | /careplus/prod/security          |
| Login de IP nunca visto antes           | WARNING    | /careplus/prod/security          |
| Token JWT expirado ou inválido          | WARNING    | /careplus/prod/security          |
| Token JWT com assinatura adulterada     | CRITICAL   | /careplus/prod/security          |
| Tentativa de acesso a rota não autorizada (403) | WARNING | /careplus/prod/application  |
| Alteração de senha de usuário           | INFO       | /careplus/prod/security          |

## 1.2 Dados Sensíveis de Saúde Mental
| Evento                                         | Severidade | Log Group                   |
|------------------------------------------------|------------|-----------------------------|
| Acesso ao histórico emocional de outro usuário | CRITICAL   | /careplus/prod/security      |
| Exportação em massa de registros de check-in   | HIGH       | /careplus/prod/security      |
| Deleção de registros em volume anormal         | HIGH       | /careplus/prod/security      |
| Acesso fora do horário comercial (0h–6h)       | WARNING    | /careplus/prod/security      |

## 1.3 Saúde da Aplicação
| Evento                                    | Severidade | Log Group                        |
|-------------------------------------------|------------|----------------------------------|
| Erro HTTP 500 (erro interno do servidor)  | HIGH       | /careplus/prod/application       |
| Taxa de erros 5xx > 10 em 5 minutos       | CRITICAL   | /careplus/prod/application       |
| Tempo de resposta > 3 segundos            | WARNING    | /careplus/prod/application       |
| Container reiniciado inesperadamente      | HIGH       | /careplus/prod/application       |
| Uso de CPU > 85% por mais de 5 minutos    | WARNING    | /careplus/prod/infrastructure    |
| Uso de memória > 90%                      | HIGH       | /careplus/prod/infrastructure    |

## 1.4 Banco de Dados
| Evento                                         | Severidade | Log Group                   |
|------------------------------------------------|------------|-----------------------------|
| Falha de conexão com o banco                   | HIGH       | /careplus/prod/application   |
| Query com tempo de execução > 10 segundos      | WARNING    | /careplus/prod/application   |
| Tentativa de DROP TABLE ou DELETE sem WHERE    | CRITICAL   | /careplus/prod/security      |
| Backup automático falhou                       | HIGH       | /careplus/prod/infrastructure|


# ============================================================
# 2. ALERTAS E THRESHOLDS
# ============================================================

## Tabela de Alertas Configurados no CloudWatch

| Alarme                        | Métrica                        | Threshold         | Período  | Ação                        |
|-------------------------------|--------------------------------|-------------------|----------|-----------------------------|
| careplus-brute-force          | FailedLoginAttempts            | > 5 em 1 minuto   | 60s      | Notificação + Bloquear IP   |
| careplus-high-error-rate      | HTTPCode_Target_5XX_Count      | > 10 em 5 minutos | 300s     | Notificação + Alerta PagerDuty |
| careplus-jwt-tampering        | InvalidJWTCount                | > 3 em 1 minuto   | 60s      | Notificação + Revogar sessões |
| careplus-slow-response        | TargetResponseTime             | > 3 segundos      | 60s      | Notificação                 |
| careplus-high-cpu             | CPUUtilization                 | > 85% por 5min    | 300s     | Notificação + Auto-scaling  |
| careplus-db-connection-fail   | DatabaseConnections            | = 0               | 60s      | Notificação CRÍTICA         |
| careplus-unauthorized-access  | HTTP403Count                   | > 20 em 5 minutos | 300s     | Notificação + Revisão manual|

## Canais de Notificação
- Severidade WARNING  → E-mail para o time de desenvolvimento
- Severidade HIGH     → E-mail + Slack #careplus-alertas
- Severidade CRITICAL → E-mail + Slack + SMS para responsável de plantão


# ============================================================
# 3. FLUXO DE RESPOSTA A INCIDENTES
# ============================================================

## Etapa 1 — DETECÇÃO
  Origem dos alertas:
  - CloudWatch Alarms (automático)
  - Revisão manual de logs (diária)
  - Relato de usuário via suporte

  Responsável: Sistema automatizado → aciona o time de segurança
  Tempo esperado: < 5 minutos para incidentes CRITICAL


## Etapa 2 — ANÁLISE E TRIAGEM
  Perguntas a responder:
  - Qual sistema foi afetado? (auth, dados, infraestrutura)
  - Quantos usuários foram impactados?
  - O incidente ainda está ativo?
  - É um falso positivo?

  Ferramentas:
  - CloudWatch Logs Insights (consultas nos logs)
  - AWS GuardDuty (detecção de ameaças)
  - Grafana (dashboard de métricas em tempo real)

  Responsável: Engenheiro de plantão
  Tempo esperado: < 15 minutos


## Etapa 3 — CONTENÇÃO
  Ações imediatas para limitar o dano:

  Cenário: Brute force / acesso suspeito
  → Bloquear IP no Security Group
  → Forçar logout de todas as sessões do usuário afetado
  → Revogar e regenerar tokens JWT

  Cenário: Vazamento de dados
  → Desativar temporariamente o endpoint afetado
  → Revogar credenciais comprometidas no Secrets Manager
  → Isolar o container comprometido

  Cenário: Aplicação fora do ar
  → Redirecionar tráfego para instância de backup
  → Reiniciar container via orquestrador
  → Acionar DBA se o problema for no banco

  Responsável: Engenheiro de plantão + Líder técnico
  Tempo esperado: < 30 minutos para contenção inicial


## Etapa 4 — ERRADICAÇÃO
  Remover a causa raiz do incidente:
  - Identificar e corrigir a vulnerabilidade explorada
  - Atualizar dependências ou imagem Docker se necessário
  - Revogar e rotacionar TODAS as credenciais potencialmente expostas
  - Aplicar patch e fazer novo deploy da aplicação
  - Executar novo scan com Trivy para validar a correção

  Responsável: Time de desenvolvimento + Segurança
  Tempo esperado: depende da complexidade (horas a dias)


## Etapa 5 — RECUPERAÇÃO
  Retornar ao estado normal de operação:
  - Restaurar serviço gradualmente (começar com % menor do tráfego)
  - Monitorar métricas por 24h após a recuperação
  - Comunicar usuários afetados se dados sensíveis foram comprometidos
  - Registrar o incidente no sistema de tickets (Azure Boards)

  Responsável: Time de desenvolvimento + Líder de produto
  Tempo esperado: < 4 horas após erradicação


## Etapa 6 — LIÇÕES APRENDIDAS (Post-Mortem)
  Reunião obrigatória até 72h após resolução do incidente.
  Documento a ser produzido:
  - Linha do tempo completa do incidente
  - Causa raiz identificada
  - O que funcionou bem na resposta
  - O que pode ser melhorado
  - Ações preventivas para evitar recorrência
  - Prazo e responsável para cada ação

  Responsável: Todo o time
  Formato: Documento no repositório em /docs/postmortem/


# ============================================================
# 4. INTEGRAÇÃO COM FERRAMENTAS
# ============================================================

## Ferramentas utilizadas (simuladas para fins acadêmicos)

| Ferramenta        | Função                                          | Status     |
|-------------------|-------------------------------------------------|------------|
| AWS CloudWatch    | Coleta de logs e métricas, alarmes automáticos  | Simulado   |
| AWS GuardDuty     | Detecção de ameaças na infraestrutura AWS       | Simulado   |
| Grafana           | Dashboard visual de métricas em tempo real      | Simulado   |
| Prometheus        | Coleta de métricas da aplicação Spring Boot     | Simulado   |
| PagerDuty         | Notificações de plantão para incidentes críticos| Simulado   |
| Slack             | Canal #careplus-alertas para notificações       | Simulado   |
| Azure Boards      | Registro e rastreamento de incidentes           | Simulado   |

## Fluxo de integração
  Aplicação Spring Boot
       ↓ métricas (Actuator)
  Prometheus → Grafana (dashboard)
       ↓ logs
  CloudWatch Logs → CloudWatch Alarms
       ↓ alarme disparado
  SNS (Simple Notification Service)
       ↓
  Slack #careplus-alertas + E-mail + PagerDuty (CRITICAL)


# ============================================================
# 5. MATRIZ DE RESPONSABILIDADES
# ============================================================

| Papel                  | Detecção | Análise | Contenção | Erradicação | Post-Mortem |
|------------------------|----------|---------|-----------|-------------|-------------|
| Sistema automatizado   |    ✔     |         |           |             |             |
| Engenheiro de plantão  |    ✔     |    ✔    |     ✔     |             |             |
| Líder técnico          |          |    ✔    |     ✔     |      ✔      |      ✔      |
| Time de desenvolvimento|          |         |           |      ✔      |      ✔      |
| Líder de produto       |          |         |           |             |      ✔      |
