FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /app

COPY pom.xml pom.xml
RUN mvn -B -DskipTests dependency:go-offline

COPY src/ src/
RUN mvn -B -DskipTests package

FROM eclipse-temurin:21-jre-jammy
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app/target/*SNAPSHOT.jar /app/app.jar

ENV APP_UPLOADS_DIR=/var/lib/supermarket/uploads
ENV MANAGEMENT_PORT=8081

EXPOSE 8080 8081
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
