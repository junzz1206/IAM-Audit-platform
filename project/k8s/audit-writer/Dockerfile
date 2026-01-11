FROM eclipse-temurin:17-jre

WORKDIR /app

# Gradle 빌드 산출물 (Spring Boot fat jar)
COPY audit-writer-0.1.0-onprem.jar /app/audit-writer.jar

ENTRYPOINT ["java", "-jar", "/app/audit-writer.jar"]

