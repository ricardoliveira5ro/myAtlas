FROM maven:3.9.11-eclipse-temurin-25 AS build
WORKDIR /workspace
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN chmod +x mvnw
RUN ./mvnw -B -q dependency:go-offline
COPY src/ src/
RUN ./mvnw -B -DskipTests package
RUN java -Djarmode=tools -jar target/social-0.0.1-SNAPSHOT.jar extract --layers --destination extracted

FROM eclipse-temurin:25-jre
WORKDIR /app
RUN useradd --system --create-home --uid 10001 appuser
COPY --from=build --chown=appuser:appuser /workspace/extracted/dependencies/ ./
COPY --from=build --chown=appuser:appuser /workspace/extracted/spring-boot-loader/ ./
COPY --from=build --chown=appuser:appuser /workspace/extracted/snapshot-dependencies/ ./
COPY --from=build --chown=appuser:appuser /workspace/extracted/application/ ./
USER 10001
EXPOSE 8084
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "org.springframework.boot.loader.launch.JarLauncher"]
