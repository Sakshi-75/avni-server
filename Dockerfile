FROM eclipse-temurin:21-jdk AS build
WORKDIR /app
COPY . .
RUN ./gradlew bootJar

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app/avni-server-api/build/libs/*.jar app.jar
EXPOSE 8021
ENTRYPOINT ["java", "-jar", "app.jar"]
