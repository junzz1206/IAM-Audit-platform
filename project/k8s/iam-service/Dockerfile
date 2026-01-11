FROM eclipse-temurin:17-jre

WORKDIR /app

# 🔥 Gradle 빌드 산출물을 그대로 사용
COPY iam-0.1.0-onprem.jar /app/iam-service.jar

ENTRYPOINT ["java", "-jar", "/app/iam-service.jar"]

