FROM docker.io/library/gradle:8-jdk21 AS build
WORKDIR /app
COPY project-api/ .
RUN gradle bootJar --no-daemon --quiet

FROM docker.io/library/openjdk:21-jre-slim
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app
COPY --from=build /app/build/libs/project-api-*.jar app.jar

RUN mkdir -p /app/logs && chown -R appuser:appuser /app
USER appuser

ENV APP_PORT=5000
ENV APP_LOG_PATH=/app/logs

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -f http://localhost:5000/api/tasks || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
