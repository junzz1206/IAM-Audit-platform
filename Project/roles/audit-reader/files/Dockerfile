FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

COPY build/libs/audit-reader-0.1.0-onprem.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java","-jar","/app/app.jar"]

