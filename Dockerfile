FROM docker.io/library/gradle:8-jdk21 AS build
WORKDIR /app
COPY project-api/ .
RUN gradle bootJar --no-daemon --quiet

FROM docker.io/library/eclipse-temurin:21-jre
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app
COPY --from=build /app/build/libs/project-api-*.jar project-api.jar

RUN mkdir -p /app/logs && chown -R appuser:appuser /app
USER appuser

ENV APP_PORT=5000
ENV APP_LOG_PATH=/app/logs

# Values are passed as --build-arg by the build scripts (sourced from
# service.environment.variables.txt). They are not baked as container-wide
# ENV; instead they are injected only into the JVM process environment via
# the generated entrypoint wrapper below.
ARG DT_TAGS=""
ARG DT_CUSTOM_PROP=""
RUN printf '#!/bin/sh\nexec env "DT_TAGS=%s" "DT_CUSTOM_PROP=%s" java -jar /app/project-api.jar "$@"\n' \
    "$DT_TAGS" "$DT_CUSTOM_PROP" > /app/entrypoint.sh && \
    chmod +x /app/entrypoint.sh

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -f http://localhost:5000/api/projects || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
