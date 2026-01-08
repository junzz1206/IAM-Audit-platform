FROM eclipse-temurin:17-jre

WORKDIR /app

# Gradle 빌드 산출물 사용
COPY build/libs/audit-query-api-0.1.0-onprem.jar /app/audit-query-api.jar

ENTRYPOINT ["java", "-jar", "/app/audit-query-api.jar"]

