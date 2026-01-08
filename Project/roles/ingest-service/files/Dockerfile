FROM eclipse-temurin:17-jre

WORKDIR /app

COPY build/libs/ingest-0.1.0-onprem.jar /app/ingest-service.jar

ENTRYPOINT ["java", "-jar", "/app/ingest-service.jar"]

