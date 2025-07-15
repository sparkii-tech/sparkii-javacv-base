# Dockerfile for sparkii-javacv-base

# 选择 jammy (Debian-based) 以确保 glibc 兼容性
FROM eclipse-temurin:21-jdk-jammy AS builder

# 安装 Maven
RUN apt-get update && \
    apt-get install -y maven && \
    apt-get clean

WORKDIR /app

# 创建一个最小化的 pom.xml，只为下载 javacv-platform 依赖
RUN echo '<xml version="1.0" encoding="UTF-8"?> \
<project xmlns="http://maven.apache.org/POM/4.0.0" \
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" \
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd"> \
    <modelVersion>4.0.0</modelVersion> \
    <groupId>com.sparkii</groupId> \
    <artifactId>javacv-deps</artifactId> \
    <version>1.0.0</version> \
    <packaging>pom</packaging> \
    <dependencies> \
        <dependency> \
            <groupId>org.bytedeco</groupId> \
            <artifactId>javacv-platform</artifactId> \
            <version>1.5.9</version> \
        </dependency> \
    </dependencies> \
</project>' > pom.xml

# 关键步骤：下载所有依赖到镜像的本地Maven仓库中
RUN mvn dependency:go-offline

# --- Final Image ---
# 最终的基础镜像使用 JRE 即可，更轻量
FROM eclipse-temurin:21-jre-jammy

# 从构建器阶段复制包含所有依赖的本地Maven仓库
COPY --from=builder /root/.m2 /root/.m2

# 验证文件是否已复制 (可选)
RUN ls -l /root/.m2/repository/org/bytedeco/javacv-platform/1.5.9/
