# Dockerfile for sparkii-javacv-base
# 构建包含javacv-platform依赖的基础镜像，用于加速sparkii-api构建

# 构建阶段 - 下载javacv-platform依赖
FROM eclipse-temurin:21-jdk-jammy AS builder

# 安装 Maven
RUN apt-get update && \
    apt-get install -y maven && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 创建一个最小化的 pom.xml，只为下载 javacv-platform 依赖
RUN echo '<?xml version="1.0" encoding="UTF-8"?> \
<project xmlns="http://maven.apache.org/POM/4.0.0" \
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" \
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd"> \
    <modelVersion>4.0.0</modelVersion> \
    <groupId>com.sparkii</groupId> \
    <artifactId>javacv-deps</artifactId> \
    <version>1.0.0</version> \
    <packaging>pom</packaging> \
    <properties> \
        <maven.compiler.source>21</maven.compiler.source> \
        <maven.compiler.target>21</maven.compiler.target> \
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding> \
    </properties> \
    <dependencies> \
        <dependency> \
            <groupId>org.bytedeco</groupId> \
            <artifactId>javacv-platform</artifactId> \
            <version>1.5.9</version> \
        </dependency> \
    </dependencies> \
</project>' > pom.xml

# 关键步骤：下载所有依赖到镜像的本地Maven仓库中
RUN mvn dependency:go-offline -B

# 验证依赖下载成功
RUN ls -la /root/.m2/repository/org/bytedeco/javacv-platform/1.5.9/ && \
    echo "JavaCV platform dependencies downloaded successfully"

# --- 最终基础镜像 ---
# 使用JDK版本以支持构建阶段使用，同时安装Maven
FROM eclipse-temurin:21-jdk-jammy

# 设置标签信息
LABEL maintainer="Sparkii Team" \
      description="Base image with pre-cached JavaCV platform dependencies" \
      version="1.5.9"

# 安装Maven和其他必要工具
RUN apt-get update && \
    apt-get install -y maven curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 从构建器阶段复制包含所有依赖的本地Maven仓库
COPY --from=builder /root/.m2 /root/.m2

# 验证文件是否已复制并设置正确的权限
RUN ls -l /root/.m2/repository/org/bytedeco/javacv-platform/1.5.9/ && \
    chmod -R 755 /root/.m2 && \
    echo "Base image ready with JavaCV dependencies"

# 设置工作目录
WORKDIR /app
