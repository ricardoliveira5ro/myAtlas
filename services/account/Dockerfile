# Package the Account service into an image—a bundle containing the Java runtime and the application
# 2 stages: one builds the application and the other assembles the smaller runtime image.

# Starts with an image that has Maven and Java 25 installed. 
FROM maven:3.9.11-eclipse-temurin-25 AS build
WORKDIR /workspace
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN chmod +x mvnw
# Downloads the dependencies listed in pom.xml. -B makes Maven run in batch mode, and -q reduces its output
RUN ./mvnw -B -q dependency:go-offline
COPY src/ src/
# Compiles the app and packages it as a runnable JAR
RUN ./mvnw -B -DskipTests package
# Unpacks the JAR into layers
RUN java -Djarmode=tools -jar target/account-0.0.1-SNAPSHOT.jar extract --layers --destination extracted


# Starts a fresh image with Java 25’s runtime environment
FROM eclipse-temurin:25-jre
WORKDIR /app
# Creates a dedicated, non-root user for running the service
RUN useradd --system --create-home --uid 10001 appuser
# Copies the unpacked JAR layers from the build stage into the runtime image, assigning their ownership to appuser.
COPY --from=build --chown=appuser:appuser /workspace/extracted/dependencies/ ./
COPY --from=build --chown=appuser:appuser /workspace/extracted/spring-boot-loader/ ./
COPY --from=build --chown=appuser:appuser /workspace/extracted/snapshot-dependencies/ ./
COPY --from=build --chown=appuser:appuser /workspace/extracted/application/ ./
USER 10001
EXPOSE 8081
# Defines the command Docker runs when the container starts. It launches the unpacked Spring Boot application. 
# MaxRAMPercentage tells Java to size its memory use based on the container’s available memory.
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "org.springframework.boot.loader.launch.JarLauncher"]
