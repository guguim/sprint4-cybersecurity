
# ============================================================
# STAGE 1 — BUILD
# Usa imagem completa do Maven apenas para compilar o projeto.
# Essa imagem nunca vai para produção — só serve para buildar.
# ============================================================
FROM maven:3.9.6-eclipse-temurin-17-alpine AS build

# Define o diretório de trabalho dentro do container
WORKDIR /app

# Copia primeiro apenas o pom.xml para aproveitar o cache do Docker.
# Se o código mudar mas as dependências não, o Maven não baixa tudo de novo.
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Agora copia o restante do código e compila
COPY src ./src
RUN mvn clean package -DskipTests -B


# ============================================================
# STAGE 2 — RUNTIME
# Imagem mínima para rodar a aplicação em produção.
# Não tem Maven, não tem código-fonte, não tem nada desnecessário.
# ============================================================
FROM eclipse-temurin:17-jre-alpine

# ────────────────────────────────────────────────────────────
# BOA PRÁTICA 1: Nunca rodar como root
# Criamos um usuário sem privilégios chamado "appuser"
# ────────────────────────────────────────────────────────────
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# ────────────────────────────────────────────────────────────
# BOA PRÁTICA 2: Diretório de trabalho dedicado
# ────────────────────────────────────────────────────────────
WORKDIR /app

# ────────────────────────────────────────────────────────────
# BOA PRÁTICA 3: Copiar apenas o JAR gerado (sem código-fonte)
# O código-fonte jamais deve estar na imagem de produção
# ────────────────────────────────────────────────────────────
COPY --from=build /app/target/*.jar app.jar

# Garante que o dono do arquivo é o appuser, não o root
RUN chown appuser:appgroup app.jar

# ────────────────────────────────────────────────────────────
# BOA PRÁTICA 4: Trocar para o usuário sem privilégios
# Toda instrução abaixo desta linha roda como "appuser"
# ────────────────────────────────────────────────────────────
USER appuser

# ────────────────────────────────────────────────────────────
# BOA PRÁTICA 5: Expor apenas a porta necessária
# A aplicação Spring Boot usa a porta 8080
# ────────────────────────────────────────────────────────────
EXPOSE 8080

# ────────────────────────────────────────────────────────────
# BOA PRÁTICA 6: Variáveis de ambiente SEM valores sensíveis
# Senhas e tokens NUNCA ficam hardcoded aqui.
# Eles são injetados em tempo de execução via Docker secrets
# ou variáveis de ambiente da plataforma (ex: Railway, ECS).
# ────────────────────────────────────────────────────────────
ENV SPRING_PROFILES_ACTIVE=prod \
    JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

# ────────────────────────────────────────────────────────────
# BOA PRÁTICA 7: Healthcheck
# O Docker verifica se a aplicação está respondendo.
# Se não responder por 3 tentativas, o container é marcado como "unhealthy".
# ────────────────────────────────────────────────────────────
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# Comando para iniciar a aplicação
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
