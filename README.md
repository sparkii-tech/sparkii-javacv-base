# 基础镜像: sparkii-javacv-base

[![构建并推送JavaCV基础镜像](https://github.com/sparkii-tech/sparkii-javacv-base/actions/workflows/build-and-push.yml/badge.svg)](https://github.com/sparkii-tech/sparkii-javacv-base/actions/workflows/build-and-push.yml)

## 1. 项目目标

本仓库包含一个专用 Docker 基础镜像的构建配置。其唯一目标是通过预先缓存一个庞大且耗时的依赖，来为核心项目 `sparkii-api` 的 **CI/CD 管线进行加速**。

---

## 2. 问题背景

`sparkii-api` 项目依赖于 `org.bytedeco:javacv-platform` 这个 Maven 依赖包。这是一个异常庞大的“胖”依赖（fat dependency），因为它捆绑了适用于多种操作系统和架构的原生 FFmpeg 库。

在标准的 CI/CD 构建流程中，Maven 每次运行时都需要下载这个巨大的文件，这会导致：
-   显著增加的构建时间。
-   更高的网络带宽消耗。
-   因网络超时或仓库暂时性问题而导致的潜在构建失败。

---

## 3. 解决方案

本项目将耗时的依赖下载步骤，从主应用的构建流程中分离出来，变成一个独立的、不频繁运行的进程。

我们构建一个 Docker 镜像，该镜像的本地 Maven 仓库缓存 (`/root/.m2`) 中已经下载好了 `javacv-platform` 依赖。然后，`sparkii-api` 应用可以直接使用这个镜像作为其运行基础，从而完全跳过在自身构建过程中下载该依赖的步骤。

### 工作原理
1.  本仓库中的 `Dockerfile` 使用一个构建器阶段（builder stage）来安装 Maven。
2.  它生成一个仅声明了 `javacv-platform` 这一个依赖的最小化 `pom.xml` 文件。
3.  执行 `mvn dependency:go-offline` 命令，该命令会将 `javacv-platform` 及其所有传递性依赖填充到镜像的本地 Maven 缓存中。
4.  最终的轻量化镜像从构建器阶段复制已填充的 Maven 缓存，然后被推送到我们的私有容器镜像仓库。

---

## 4. 自动化与发布

整个过程通过 `.github/workflows/build-and-push.yml` GitHub Actions 工作流完全自动化。

-   **触发器:** 每当有更改被推送到 `main` 分支时，工作流会自动运行。
-   **操作:** 如上所述，构建 Docker 镜像。
-   **目的地:** 构建完成的镜像被推送到我们的私有 **Amazon ECR** 仓库。

镜像使用以下方案进行标记：
-   `latest`
-   `javacv-platform` 的具体版本号 (例如, `1.5.9`)
-   简短的 Git 提交 SHA 值

---

## 5. 在下游项目中使用

要在 `sparkii-api` 项目（或任何其他 Java 项目）中使用此基础镜像，需要进行两处更改：

#### a) 更新 `pom.xml`
必须将该依赖的 scope（作用域）更改为 `provided`。这会告诉 Maven，该依赖在编译时是必需的，但不应被打包到最终的 JAR 文件中，因为它将由运行时环境（也就是我们的 Docker 镜像）提供。

```xml
<dependency>
    <groupId>org.bytedeco</groupId>
    <artifactId>javacv-platform</artifactId>
    <version>1.5.9</version>
    <scope>provided</scope>
</dependency>
```

#### b) 更新 `Dockerfile`
应用程序的 `Dockerfile` 应在其最终的运行阶段（runtime stage）使用此镜像。

```dockerfile
# --- 构建阶段 ---
# ... (应用构建逻辑保持不变)


# --- 运行阶段 ---
# 从 ECR 使用我们预构建的基础镜像
FROM 194722441610.dkr.ecr.us-west-2.amazonaws.com/sparkii-javacv-base:latest

# ... (应用的其余运行时配置)
```

---

## 6. 维护

如需更新此基础镜像中使用的 `javacv-platform` 版本，只需修改 `Dockerfile` 中 `echo` 命令里的版本号，然后将更改推送到 `main` 分支即可。后续的构建和发布将由自动化流程处理。
