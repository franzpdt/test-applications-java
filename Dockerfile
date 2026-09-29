FROM docker.io/library/gradle:8.14.5-jdk21 AS build
WORKDIR /app
COPY project-api/ .
RUN gradle bootJar --no-daemon --quiet

FROM docker.io/library/eclipse-temurin:21.0.11_10-jre
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app
COPY --from=build /app/build/libs/project-api-*.jar project-api.jar

RUN mkdir -p /app/logs && chown -R appuser:appuser /app
USER appuser

ENV APP_PORT=5000
ENV APP_LOG_PATH=/app/logs

# DT_TAGS / DT_CUSTOM_PROP are NOT baked into the image. They are supplied at
# deploy time as container environment variables (k8s: injected into the pod
# spec from ONEAGENT_PROCESS_TAGS / ONEAGENT_CUSTOM_PROP; systemd: via the
# service.environment.variables.txt EnvironmentFile). The JVM inherits them.

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -f http://localhost:5000/api/projects || exit 1

ENTRYPOINT ["java", "-jar", "/app/project-api.jar"]
