FROM eclipse-temurin:17-jre
WORKDIR /app

# 🔥 반드시 -plain 없는 JAR
COPY finance-rule-engine-0.1.0-onprem.jar /app/finance-rule-engine.jar

ENTRYPOINT ["java","-jar","/app/finance-rule-engine.jar"]
