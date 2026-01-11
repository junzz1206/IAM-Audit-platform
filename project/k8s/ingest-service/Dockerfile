FROM eclipse-temurin:17-jre

WORKDIR /app

COPY ingest-0.1.0-onprem.jar /app/ingest-service.jar

ENTRYPOINT ["java", "-jar", "/app/ingest-service.jar"]

