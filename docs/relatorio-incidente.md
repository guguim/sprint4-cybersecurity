# ============================================================
# RELATÓRIO DE INCIDENTE SIMULADO
# Projeto: Challenge Care Plus 2025 — Sprint 4 Cibersegurança
# Serviço: Check-in de Saúde Mental e Estresse
# Incidente: INC-2025-001 — Vazamento de Token JWT
# ============================================================


# ============================================================
# 1. IDENTIFICAÇÃO DO INCIDENTE
# ============================================================

  ID do Incidente : INC-2025-001
  Tipo            : Vazamento de credencial / Token JWT exposto
  Severidade      : CRITICAL
  Status          : Resolvido
  Data de abertura: 2025-11-10 02:17:43 UTC
  Data de fechamento: 2025-11-10 05:44:00 UTC
  Duração total   : 3 horas e 27 minutos
  Sistemas afetados: API REST de autenticação, módulo de check-in emocional
  Usuários afetados: 1 conta comprometida (dados de saúde mental expostos)


# ============================================================
# 2. DESCRIÇÃO DO INCIDENTE
# ============================================================

  Durante o desenvolvimento de uma nova feature, um desenvolvedor
  do time cometeu acidentalmente um arquivo de configuração local
  (.env) contendo o JWT_SECRET da aplicação em um repositório
  público no GitHub.

  Um agente externo identificou o segredo exposto por meio de
  ferramentas automatizadas de varredura de repositórios públicos
  (conhecidas como "secret scanners"). Com a chave em mãos, o
  atacante foi capaz de forjar tokens JWT válidos e se autenticar
  como um usuário real da plataforma Care Plus, acessando seus
  registros de saúde mental sem autorização.

  O incidente foi detectado pelo alarme "careplus-jwt-tampering"
  do CloudWatch, que identificou tokens JWT com assinatura válida
  mas originados de IP desconhecido, às 02:17 UTC.


# ============================================================
# 3. LINHA DO TEMPO DO INCIDENTE
# ============================================================

  [2025-11-09 19:42:00 UTC] — ORIGEM
  Desenvolvedor faz commit acidental do arquivo ".env" contendo
  JWT_SECRET=s3cr3t-careplus-jwt-2025 em repositório público.
  O repositório era privado mas foi temporariamente tornado público
  durante uma demo para um cliente.

  [2025-11-09 19:43:00 UTC] — EXPOSIÇÃO
  GitHub Secret Scanning detecta o segredo e envia alerta por
  e-mail para o repositório. O e-mail não foi lido imediatamente.

  [2025-11-09 23:55:00 UTC] — COMPROMETIMENTO
  Ferramenta automatizada de terceiros (TruffleHog/GitLeaks) varre
  repositórios públicos recentes e identifica o JWT_SECRET exposto.
  Segredo é capturado pelo agente externo.

  [2025-11-10 02:14:11 UTC] — ATAQUE INICIA
  Atacante usa o JWT_SECRET para forjar token JWT com payload:
  { "sub": "user_4821", "role": "USER", "iat": ... }
  e começa a fazer requisições autenticadas à API do Care Plus.

  [2025-11-10 02:17:43 UTC] — DETECÇÃO
  Alarme "careplus-jwt-tampering" dispara no CloudWatch:
  3 tokens JWT com assinatura válida, mas gerados fora da
  aplicação (claim "iss" ausente), vindos do IP 198.51.100.42.

  [2025-11-10 02:19:00 UTC] — NOTIFICAÇÃO
  PagerDuty aciona o engenheiro de plantão via SMS e Slack.
  Canal #careplus-alertas recebe alerta automático.

  [2025-11-10 02:24:00 UTC] — ENGENHEIRO ASSUME
  Engenheiro de plantão confirma o incidente (não é falso positivo)
  e aciona o líder técnico.

  [2025-11-10 02:31:00 UTC] — CONTENÇÃO
  JWT_SECRET revogado e regenerado no AWS Secrets Manager.
  Todas as sessões ativas são invalidadas (blacklist de JTI).
  IP 198.51.100.42 bloqueado no Security Group.
  Repositório tornado privado novamente.

  [2025-11-10 02:35:00 UTC] — ACESSO ENCERRADO
  Atacante perde acesso. Últimas requisições retornam HTTP 401.

  [2025-11-10 03:10:00 UTC] — ANÁLISE FORENSE
  Logs analisados: o atacante acessou 47 endpoints em 21 minutos.
  Dados acessados: registros de check-in emocional do user_4821
  (nome, histórico de humor, nível de estresse dos últimos 30 dias).
  Nenhum dado foi alterado ou deletado.

  [2025-11-10 04:00:00 UTC] — ERRADICAÇÃO
  Novo deploy da aplicação com JWT_SECRET atualizado.
  Arquivo ".env" removido do histórico do Git (git filter-repo).
  Pre-commit hook instalado para bloquear commits com segredos.

  [2025-11-10 05:44:00 UTC] — RESOLUÇÃO
  Serviço operando normalmente. Incidente encerrado.
  Usuário afetado notificado conforme LGPD.


# ============================================================
# 4. EVIDÊNCIAS (LOGS SIMULADOS)
# ============================================================

## 4.1 Log do CloudWatch — Alarme disparado

  2025-11-10T02:17:43Z [CRITICAL] careplus-jwt-tampering ALARM
  Metric    : InvalidJWTCount
  Value     : 3 (threshold: 3)
  Period    : 60s
  Source IP : 198.51.100.42
  Detail    : JWT tokens with valid signature but missing 'iss' claim
              detected. Possible token forgery attack.
  Action    : SNS notification sent → PagerDuty + Slack


## 4.2 Logs da Aplicação — Requisições do atacante

  2025-11-10T02:14:11Z INFO  AuthFilter     - JWT validated | user=user_4821 | ip=198.51.100.42
  2025-11-10T02:14:12Z INFO  CheckinController - GET /api/v1/checkin/history | user=user_4821 | status=200
  2025-11-10T02:14:15Z INFO  CheckinController - GET /api/v1/checkin/report  | user=user_4821 | status=200
  2025-11-10T02:15:01Z WARN  AuthFilter     - JWT missing 'iss' claim | user=user_4821 | ip=198.51.100.42
  2025-11-10T02:15:02Z WARN  AuthFilter     - JWT missing 'iss' claim | user=user_4821 | ip=198.51.100.42
  2025-11-10T02:15:03Z WARN  AuthFilter     - JWT missing 'iss' claim | user=user_4821 | ip=198.51.100.42
  2025-11-10T02:17:43Z CRITICAL SecurityMonitor - ALARM: 3 invalid JWT claims in 60s | ip=198.51.100.42
  2025-11-10T02:35:22Z INFO  AuthFilter     - JWT signature invalid (secret rotated) | ip=198.51.100.42
  2025-11-10T02:35:22Z WARN  AuthFilter     - Unauthorized request blocked | ip=198.51.100.42 | status=401
  2025-11-10T02:35:23Z WARN  AuthFilter     - Unauthorized request blocked | ip=198.51.100.42 | status=401


## 4.3 Log do AWS Secrets Manager — Rotação do segredo

  2025-11-10T02:31:05Z INFO  SecretsManager - Secret rotation initiated
  Secret    : careplus/prod/jwt-secret
  Initiated : engenheiro-plantao@careplus.com.br
  Reason    : Security incident INC-2025-001
  2025-11-10T02:31:08Z INFO  SecretsManager - New secret version created
  Version   : careplus/prod/jwt-secret:v2
  Status    : AWSCURRENT
  2025-11-10T02:31:08Z INFO  SecretsManager - Previous version marked AWSPREVIOUS
  2025-11-10T02:31:10Z INFO  Application    - JWT_SECRET reloaded successfully


## 4.4 Log do Security Group — Bloqueio de IP

  2025-11-10T02:31:15Z INFO  AWS-EC2        - Security Group rule added
  Group     : careplus-app-sg
  Rule      : DENY inbound TCP from 198.51.100.42/32
  Added by  : engenheiro-plantao@careplus.com.br
  Reason    : Malicious IP - Incident INC-2025-001


# ============================================================
# 5. ANÁLISE DA CAUSA RAIZ
# ============================================================

  Causa raiz primária:
  Arquivo ".env" com segredo de produção (JWT_SECRET) commitado
  acidentalmente em repositório Git que foi tornado público.

  Causas contribuintes:
  1. Ausência de pre-commit hook para detectar segredos antes do commit
  2. Arquivo ".env" não estava no ".gitignore" do projeto
  3. Alerta do GitHub Secret Scanning não foi lido a tempo
  4. JWT_SECRET de produção estava sendo usado em ambiente de desenvolvimento
  5. Tokens JWT não tinham claim "iss" (issuer), dificultando a detecção
     de tokens forjados externamente


# ============================================================
# 6. AÇÕES CORRETIVAS (o que foi feito para resolver)
# ============================================================

  [✔] JWT_SECRET revogado e regenerado imediatamente
  [✔] Todas as sessões ativas invalidadas via blacklist de JTI
  [✔] IP do atacante bloqueado no Security Group
  [✔] Arquivo ".env" removido do histórico Git (git filter-repo)
  [✔] Repositório tornado privado
  [✔] Usuário afetado (user_4821) notificado via e-mail (LGPD Art. 48)
  [✔] Novo deploy realizado com segredo atualizado


# ============================================================
# 7. AÇÕES PREVENTIVAS (para não acontecer de novo)
# ============================================================

  [1] Instalar pre-commit hook com GitLeaks em todos os repositórios
      Responsável: Time DevOps | Prazo: 3 dias

  [2] Adicionar ".env", "*.key", "*.pem" ao ".gitignore" global
      Responsável: Todos os desenvolvedores | Prazo: imediato

  [3] Separar segredos de dev e produção — produção NUNCA sai da AWS
      Responsável: Líder técnico | Prazo: 1 semana

  [4] Adicionar claim "iss" (issuer) em todos os tokens JWT gerados
      Responsável: Time backend | Prazo: próximo sprint

  [5] Configurar rotação automática do JWT_SECRET a cada 90 dias
      Responsável: Time DevOps | Prazo: 1 semana

  [6] Treinamento de segurança para todo o time de desenvolvimento
      Responsável: Líder técnico | Prazo: 2 semanas

  [7] Ativar GitHub Advanced Security com Secret Scanning em todos repos
      Responsável: Time DevOps | Prazo: imediato


# ============================================================
# 8. IMPACTO FINAL
# ============================================================

  Dados expostos    : Registros de check-in emocional de 1 usuário
                      (histórico de humor e estresse dos últimos 30 dias)
  Dados alterados   : Nenhum
  Dados deletados   : Nenhum
  Usuários afetados : 1
  Tempo de exposição: 2 horas e 21 minutos (19:42 – 02:14 UTC)
  Tempo de resposta : 7 minutos da detecção à contenção (02:17 – 02:31)
  Notificação LGPD  : Realizada em até 72h conforme exigido pela Lei


# ============================================================
# 9. LIÇÕES APRENDIDAS
# ============================================================

  O incidente demonstrou que controles preventivos são mais eficazes
  do que reativos. A detecção foi rápida (7 minutos), mas o dano já
  havia ocorrido. Com o pre-commit hook e o .gitignore corretos,
  o segredo jamais teria chegado ao repositório.

  O tempo de resposta da equipe foi satisfatório, mas o alerta do
  GitHub Secret Scanning enviado às 19:43 não foi lido. Isso mostra
  a importância de centralizar alertas em canais monitorados ativamente
  (Slack, PagerDuty) em vez de depender apenas de e-mail.


# ============================================================
# RESPONSÁVEIS PELO DOCUMENTO
# ============================================================

  Enzo Rodrigues   — RM553377
  Gabriel Mediotti — RM552632
  Hugo Santos      — RM553266
  Maria Júlia      — RM553384
  Rafael Cristofali— RM553521

  Turma: Engenharia de Software — 3º Ano
  Disciplina: Cybersecurity — Challenge Care Plus 2025
