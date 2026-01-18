#
# Multi-stage build for Spring Boot (Gradle) app
# Production-ready Dockerfile for Java 21
#

FROM eclipse-temurin:21-jdk AS build
WORKDIR /app

# Copy Gradle wrapper and build files
COPY gradlew gradlew.bat build.gradle settings.gradle /app/
COPY gradle /app/gradle

# Copy source code
COPY src /app/src

# Build application (skip tests for faster builds)
RUN chmod +x /app/gradlew && /app/gradlew clean bootJar -x test

# Runtime stage
FROM eclipse-temurin:21-jre
WORKDIR /app

# Install curl for healthcheck
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Set timezone
ENV TZ=UTC
ENV JAVA_OPTS="-Xmx512m -Xms256m"

# Create non-root user for security
RUN groupadd -r spring && useradd -r -g spring spring
RUN chown -R spring:spring /app
USER spring:spring

# Copy built JAR from build stage
COPY --from=build --chown=spring:spring /app/build/libs/*.jar /app/app.jar

EXPOSE 8080

# Health check (using root endpoint since actuator is not included)
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1

# Use exec form for better signal handling
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
