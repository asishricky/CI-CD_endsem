# ---------- Build stage ----------
# Use Maven image with Temurin JDK for building
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app

# Copy pom first to leverage Docker layer caching for dependencies
COPY pom.xml ./

# Use BuildKit cache for ~/.m2 (enable BuildKit in your environment)
# This downloads dependencies offline to speed up subsequent builds
RUN --mount=type=cache,target=/root/.m2 mvn -B -DskipTests dependency:go-offline

# Copy source and build
COPY src ./src
# Build the jar (skip tests in CI/lab environment)
RUN --mount=type=cache,target=/root/.m2 mvn -B -DskipTests clean package

# ---------- Run stage ----------
# Use lightweight Temurin JRE Alpine image for runtime
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Create a non-root user and use it
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Copy the built jar from the build stage
COPY --from=build --chown=appuser:appgroup /app/target/*.jar app.jar

# Allow overriding JVM options at runtime
ENV JAVA_OPTS=""

# Expose the port your app listens to
EXPOSE 8081

# Optional: simple healthcheck (adjust or remove if your app has no /actuator/health)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- --timeout=2 http://127.0.0.1:8081/actuator/health || exit 1

# Start the application (keeps shell substitution for JAVA_OPTS)
ENTRYPOINT ["sh","-c","java $JAVA_OPTS -jar app.jar"]
