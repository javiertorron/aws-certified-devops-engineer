# AWS CodeBuild - Comprehensive Guide

## Table of Contents
1. [CodeBuild Fundamentals](#1-codebuild-fundamentals)
2. [Build Specification (buildspec.yml)](#2-build-specification-buildspecyml)
3. [Build Environments and Customization](#3-build-environments-and-customization)
4. [Advanced Build Configurations](#4-advanced-build-configurations)
5. [Security and Compliance](#5-security-and-compliance)
6. [Integration Patterns](#6-integration-patterns)
7. [Monitoring and Observability](#7-monitoring-and-observability)
8. [Enterprise and Advanced Features](#8-enterprise-and-advanced-features)

---

## 1. CodeBuild Fundamentals

### Service Architecture and Core Concepts

AWS CodeBuild is a fully managed build service that eliminates the need to provision, manage, and scale build servers. It provides pre-configured build environments for popular programming languages and build tools.

#### Key Components

**Build Projects**
- Central configuration unit that defines how CodeBuild runs a build
- Contains source location, build environment, build commands, and output locations
- Can be created via Console, CLI, CloudFormation, or APIs

**Build Environments**
- Compute environment where builds are executed
- Includes operating system, runtime, and tools
- Can be AWS-managed or custom Docker images

**Build Phases**
- Logical groupings of build commands
- Standard phases: install, pre_build, build, post_build
- Each phase can contain multiple commands

#### CodeBuild Architecture

```mermaid
graph TB
    A[Source Repository] --> B[CodeBuild Project]
    B --> C[Build Environment]
    C --> D[Build Execution]
    D --> E[Artifacts]
    D --> F[Logs]
    E --> G[S3/ECR/Other]
    F --> H[CloudWatch Logs]
```

### Build Project Configuration

#### Essential Configuration Elements

1. **Source Configuration**
   - Source provider (CodeCommit, GitHub, S3, etc.)
   - Repository location and authentication
   - Source version (branch, tag, commit)
   - Build trigger configuration

2. **Environment Configuration**
   - Compute type (build.general1.small to build.general1.2xlarge)
   - Operating system (Amazon Linux, Ubuntu, Windows)
   - Runtime versions and language environments
   - Environment variables and secrets

3. **Buildspec Configuration**
   - Inline buildspec or buildspec.yml file location
   - Build commands and phases
   - Artifact specifications

4. **Service Role**
   - IAM role that CodeBuild assumes during build execution
   - Must have permissions for source access, artifact storage, and logging

#### Sample Build Project Configuration (CLI)

```bash
aws codebuild create-project \
  --name my-build-project \
  --source type=CODECOMMIT,location=https://git-codecommit.region.amazonaws.com/v1/repos/my-repo \
  --artifacts type=S3,location=my-build-artifacts/builds \
  --environment type=LINUX_CONTAINER,image=aws/codebuild/amazonlinux2-x86_64-standard:3.0,computeType=BUILD_GENERAL1_MEDIUM \
  --service-role arn:aws:iam::account:role/service-role/codebuild-service-role
```

### Build Environments and Compute Types

#### Managed Build Environments

AWS provides curated build images optimized for different use cases:

**Amazon Linux 2**
```yaml
Environment:
  Type: LINUX_CONTAINER
  Image: aws/codebuild/amazonlinux2-x86_64-standard:3.0
  ComputeType: BUILD_GENERAL1_MEDIUM
  RuntimeVersions:
    python: 3.8
    nodejs: 14
    java: corretto11
```

**Ubuntu**
```yaml
Environment:
  Type: LINUX_CONTAINER
  Image: aws/codebuild/standard:5.0
  ComputeType: BUILD_GENERAL1_LARGE
  RuntimeVersions:
    python: 3.9
    nodejs: 16
    dotnet: 5.0
```

**Windows**
```yaml
Environment:
  Type: WINDOWS_SERVER_2019_CONTAINER
  Image: aws/codebuild/windows-base:2019-1.0
  ComputeType: BUILD_GENERAL1_LARGE
```

#### Compute Types and Specifications

| Compute Type | vCPUs | Memory (GB) | Disk Space (GB) | Use Case |
|--------------|--------|-------------|-----------------|----------|
| BUILD_GENERAL1_SMALL | 2 | 3 | 64 | Small projects, quick builds |
| BUILD_GENERAL1_MEDIUM | 4 | 7 | 128 | Medium projects, typical builds |
| BUILD_GENERAL1_LARGE | 8 | 15 | 128 | Large projects, parallel builds |
| BUILD_GENERAL1_2XLARGE | 36 | 72 | 128 | Very large projects, intensive builds |

### Source Providers and Authentication

#### Supported Source Providers

**AWS CodeCommit**
```json
{
  "type": "CODECOMMIT",
  "location": "https://git-codecommit.region.amazonaws.com/v1/repos/my-repo",
  "sourceVersion": "refs/heads/main",
  "buildspec": "buildspec.yml"
}
```

**GitHub**
```json
{
  "type": "GITHUB",
  "location": "https://github.com/user/repo",
  "auth": {
    "type": "OAUTH"
  },
  "webhook": {
    "filterGroups": [
      [
        {
          "type": "EVENT",
          "pattern": "PUSH"
        },
        {
          "type": "HEAD_REF",
          "pattern": "^refs/heads/main$"
        }
      ]
    ]
  }
}
```

**Amazon S3**
```json
{
  "type": "S3",
  "location": "my-source-bucket/source.zip",
  "buildspec": "path/to/buildspec.yml"
}
```

#### Authentication Methods

**CodeCommit**: Uses IAM roles and policies
**GitHub**: OAuth tokens or personal access tokens
**Bitbucket**: App passwords or OAuth
**S3**: IAM permissions for bucket access

### Build Lifecycle and Phases

#### Standard Build Phases

1. **SUBMITTED**: Build request submitted to CodeBuild
2. **QUEUED**: Build placed in queue waiting for available capacity
3. **PROVISIONING**: Build environment being provisioned
4. **DOWNLOAD_SOURCE**: Source code being downloaded
5. **INSTALL**: Install phase commands executed
6. **PRE_BUILD**: Pre-build phase commands executed
7. **BUILD**: Build phase commands executed
8. **POST_BUILD**: Post-build phase commands executed
9. **UPLOAD_ARTIFACTS**: Artifacts being uploaded to specified location
10. **FINALIZING**: Build environment cleanup
11. **COMPLETED**: Build finished successfully or failed

#### Phase Execution Flow

```yaml
version: 0.2

phases:
  install:
    runtime-versions:
      nodejs: 14
    commands:
      - echo Installing dependencies
      - npm install
  
  pre_build:
    commands:
      - echo Pre-build phase
      - npm run lint
      - npm run test:unit
  
  build:
    commands:
      - echo Build phase
      - npm run build
      - npm run test:integration
  
  post_build:
    commands:
      - echo Post-build phase
      - npm run test:e2e
      - echo Build completed
```

---

## 2. Build Specification (buildspec.yml)

### Buildspec Syntax and Structure

The buildspec file defines the build commands and settings used by CodeBuild. It can be included in the source code root or specified inline in the build project.

#### Basic Buildspec Structure

```yaml
version: 0.2

# Global environment variables
env:
  variables:
    NODE_ENV: production
    BUILD_NUMBER: $CODEBUILD_BUILD_NUMBER
  parameter-store:
    DATABASE_URL: /myapp/database/url
  secrets-manager:
    API_KEY: prod/myapp/apikey:key

# Build phases
phases:
  install:
    runtime-versions:
      nodejs: 16
      python: 3.9
    commands:
      - echo Installing dependencies
      
  pre_build:
    commands:
      - echo Pre-build phase started
      
  build:
    commands:
      - echo Build phase started
      
  post_build:
    commands:
      - echo Build completed

# Artifacts configuration
artifacts:
  files:
    - '**/*'
  base-directory: dist
  name: myapp-$CODEBUILD_BUILD_NUMBER

# Build caching
cache:
  paths:
    - node_modules/**/*
    - .gradle/caches/**/*
```

### Environment Variables and Parameter Handling

#### Variable Precedence (highest to lowest)
1. Buildspec environment variables
2. Build project environment variables
3. Compute environment variables

#### Built-in Environment Variables

CodeBuild provides numerous built-in environment variables:

```bash
# Build Information
CODEBUILD_BUILD_ARN
CODEBUILD_BUILD_ID  
CODEBUILD_BUILD_NUMBER
CODEBUILD_BUILD_SUCCEEDING

# Source Information  
CODEBUILD_SOURCE_REPO_URL
CODEBUILD_SOURCE_VERSION
CODEBUILD_RESOLVED_SOURCE_VERSION

# Build Environment
CODEBUILD_BUILD_IMAGE
CODEBUILD_WEBHOOK_HEAD_REF
CODEBUILD_WEBHOOK_EVENT
```

#### Advanced Environment Variable Usage

```yaml
version: 0.2

env:
  variables:
    # Static variables
    ENVIRONMENT: production
    REGION: us-west-2
    
  # Parameter Store integration
  parameter-store:
    DB_PASSWORD: /myapp/prod/db/password
    REDIS_URL: /myapp/prod/redis/url
    
  # Secrets Manager integration  
  secrets-manager:
    API_TOKEN: prod/myapp/tokens:github_token
    PRIVATE_KEY: prod/myapp/keys:signing_key
    
  # Exported variables (available in subsequent phases)
  exported-variables:
    - BUILD_VERSION
    - ARTIFACT_LOCATION

phases:
  pre_build:
    commands:
      - export BUILD_VERSION="1.0.${CODEBUILD_BUILD_NUMBER}"
      - export ARTIFACT_LOCATION="s3://my-artifacts/${BUILD_VERSION}"
      - echo "Building version $BUILD_VERSION"
```

### Build Phases Deep Dive

#### Install Phase

The install phase is for installing packages in the build environment:

```yaml
phases:
  install:
    # Specify runtime versions
    runtime-versions:
      nodejs: 16
      python: 3.9
      java: corretto11
      
    commands:
      # System dependencies
      - apt-get update
      - apt-get install -y jq curl
      
      # Language-specific dependencies
      - npm install -g typescript @angular/cli
      - pip install --upgrade pip setuptools wheel
      - pip install -r requirements.txt
      
      # Custom tool installation
      - curl -o kubectl https://amazon-eks.s3.region.amazonaws.com/kubectl
      - chmod +x ./kubectl
      - mv ./kubectl /usr/local/bin
```

#### Pre-build Phase

Used for commands that need to run before the build:

```yaml
phases:
  pre_build:
    commands:
      # Authentication
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REPOSITORY_URI
      
      # Environment preparation
      - echo Setting up environment...
      - export IMAGE_TAG=${CODEBUILD_BUILD_NUMBER}
      - export IMAGE_URI=${ECR_REPOSITORY_URI}:${IMAGE_TAG}
      
      # Code quality checks
      - echo Running linter...
      - npm run lint
      - echo Running unit tests...
      - npm run test:unit
      
      # Security scanning
      - echo Running security scan...
      - npm audit --audit-level moderate
```

#### Build Phase

The main build logic:

```yaml
phases:
  build:
    commands:
      # Application build
      - echo Build started on `date`
      - echo Building the application...
      - npm run build
      
      # Docker build (if containerizing)
      - echo Building Docker image...
      - docker build -t $IMAGE_URI .
      - docker tag $IMAGE_URI $ECR_REPOSITORY_URI:latest
      
      # Integration tests
      - echo Running integration tests...
      - npm run test:integration
      
      # Build artifacts
      - echo Creating deployment package...
      - zip -r deployment-package.zip dist/ package.json
```

#### Post-build Phase

Cleanup and artifact preparation:

```yaml
phases:
  post_build:
    commands:
      # Docker push (if using containers)
      - echo Build completed on `date`
      - echo Pushing Docker image...
      - docker push $IMAGE_URI
      - docker push $ECR_REPOSITORY_URI:latest
      
      # End-to-end tests
      - echo Running e2e tests...
      - npm run test:e2e
      
      # Generate reports
      - echo Generating test reports...
      - npm run test:coverage
      
      # Cleanup
      - echo Cleaning up temporary files...
      - rm -rf node_modules/.cache
      
    finally:
      # Commands that run regardless of build success/failure
      - echo Uploading test results...
      - aws s3 cp test-results/ s3://my-test-results/ --recursive
```

### Artifact Management and Output Configuration

#### Basic Artifacts Configuration

```yaml
artifacts:
  files:
    - '**/*'
  base-directory: build
  name: myapp-$CODEBUILD_BUILD_NUMBER
  secondary-artifacts:
    reports:
      files:
        - 'coverage/**/*'
        - 'test-results/**/*'
      base-directory: reports
      name: test-reports-$CODEBUILD_BUILD_NUMBER
```

#### Advanced Artifacts with Multiple Outputs

```yaml
artifacts:
  # Primary artifacts
  files:
    - dist/**/*
    - package.json
    - serverless.yml
  exclude-paths:
    - dist/**/*.map
    - dist/**/*.test.js
  base-directory: '.'
  name: deployment-package-$CODEBUILD_BUILD_NUMBER.zip
  
  # Secondary artifacts
  secondary-artifacts:
    source-code:
      files:
        - src/**/*
        - package.json
      name: source-$CODEBUILD_BUILD_NUMBER.zip
      
    documentation:
      files:
        - docs/**/*
        - README.md
      name: docs-$CODEBUILD_BUILD_NUMBER.zip
      
    docker-images:
      files:
        - imagedefinitions.json
      name: docker-images-$CODEBUILD_BUILD_NUMBER
```

### Advanced Buildspec Patterns

#### Conditional Logic and Branching

```yaml
version: 0.2

phases:
  install:
    runtime-versions:
      nodejs: 16
    commands:
      - npm install
      
  pre_build:
    commands:
      - |
        if [ "$CODEBUILD_WEBHOOK_HEAD_REF" = "refs/heads/main" ]; then
          echo "Building production version"
          export NODE_ENV=production
          export DEPLOY_ENVIRONMENT=prod
        elif [ "$CODEBUILD_WEBHOOK_HEAD_REF" = "refs/heads/develop" ]; then
          echo "Building staging version"
          export NODE_ENV=staging
          export DEPLOY_ENVIRONMENT=staging
        else
          echo "Building development version"
          export NODE_ENV=development
          export DEPLOY_ENVIRONMENT=dev
        fi
        
  build:
    commands:
      - npm run build:$NODE_ENV
      - |
        if [ "$DEPLOY_ENVIRONMENT" = "prod" ]; then
          npm run test:all
          npm run security:scan
        else
          npm run test:unit
        fi

  post_build:
    commands:
      - |
        if [ "$CODEBUILD_BUILD_SUCCEEDING" = "1" ]; then
          echo "Build succeeded, preparing deployment"
          aws s3 cp dist/ s3://deployments-$DEPLOY_ENVIRONMENT/ --recursive
        else
          echo "Build failed, skipping deployment"
        fi
```

#### Multi-platform Build Configuration

```yaml
version: 0.2

batch:
  fast-fail: false
  build-list:
    - identifier: linux_build
      env:
        type: LINUX_CONTAINER
        image: aws/codebuild/amazonlinux2-x86_64-standard:3.0
        
    - identifier: windows_build  
      env:
        type: WINDOWS_CONTAINER
        image: aws/codebuild/windows-base:2019-1.0
        
phases:
  install:
    commands:
      - |
        if [ "$CODEBUILD_BUILD_IMAGE" = "aws/codebuild/amazonlinux2-x86_64-standard:3.0" ]; then
          echo "Linux build environment"
          yum update -y
          yum install -y docker
        else
          echo "Windows build environment" 
          choco install docker-desktop
        fi
        
  build:
    commands:
      - echo "Building for platform: $CODEBUILD_BUILD_IMAGE"
      - npm run build
      
artifacts:
  files:
    - 'dist/**/*'
  name: app-$CODEBUILD_BUILD_IMAGE-$CODEBUILD_BUILD_NUMBER
```

#### Complex Multi-Service Build

```yaml
version: 0.2

env:
  variables:
    SERVICES: "api,frontend,worker,scheduler"
    
phases:
  install:
    runtime-versions:
      nodejs: 16
      python: 3.9
    commands:
      - pip install awscli
      - npm install -g lerna
      
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      - echo Setting up build environment...
      - lerna bootstrap
      
  build:
    commands:
      - echo Starting multi-service build...
      - |
        for service in ${SERVICES//,/ }; do
          echo "Building $service..."
          cd services/$service
          
          # Run tests
          npm test
          
          # Build application
          npm run build
          
          # Build Docker image
          docker build -t $service:$CODEBUILD_BUILD_NUMBER .
          docker tag $service:$CODEBUILD_BUILD_NUMBER $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$service:$CODEBUILD_BUILD_NUMBER
          docker tag $service:$CODEBUILD_BUILD_NUMBER $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$service:latest
          
          # Push to ECR
          docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$service:$CODEBUILD_BUILD_NUMBER
          docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$service:latest
          
          cd ../../
        done
        
  post_build:
    commands:
      - echo Generating deployment configuration...
      - |
        cat > imagedefinitions.json << EOF
        [
          $(for service in ${SERVICES//,/ }; do
            echo "  {\"name\": \"$service\", \"imageUri\": \"$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$service:$CODEBUILD_BUILD_NUMBER\"},"
          done | sed '$ s/,$//')
        ]
        EOF

artifacts:
  files:
    - imagedefinitions.json
    - services/*/dist/**/*
  name: multi-service-build-$CODEBUILD_BUILD_NUMBER
```

---

## 3. Build Environments and Customization

### Managed Build Environments

AWS CodeBuild provides curated build images that include popular tools and runtimes. These images are regularly updated and optimized for common build scenarios.

#### Available Image Categories

**Standard Images**
- Amazon Linux 2 based
- Include multiple language runtimes
- Pre-installed build tools and utilities
- Regular security and feature updates

**Specialized Images**
- Language-specific optimizations
- Framework-specific tools pre-installed
- Smaller footprint for specific use cases

#### Runtime Version Management

```yaml
version: 0.2

phases:
  install:
    runtime-versions:
      # Node.js versions
      nodejs: 16  # or 14, 12
      
      # Python versions  
      python: 3.9  # or 3.8, 3.7
      
      # Java versions
      java: corretto11  # or corretto8, openjdk11, openjdk8
      
      # .NET versions
      dotnet: 5.0  # or 3.1, 2.1
      
      # Go versions
      golang: 1.16  # or 1.15, 1.14
      
      # PHP versions
      php: 7.4  # or 8.0, 7.3
      
      # Ruby versions
      ruby: 2.7  # or 2.6, 2.5
      
    commands:
      # Verify installed versions
      - node --version
      - python --version
      - java -version
```

### Custom Build Environments

When managed environments don't meet specific requirements, you can create custom Docker images hosted in ECR or Docker Hub.

#### Creating Custom Build Images

**Dockerfile for Custom Build Environment**

```dockerfile
# Base image
FROM amazonlinux:2

# Install system dependencies
RUN yum update -y && \
    yum install -y \
    git \
    curl \
    tar \
    gzip \
    unzip \
    which \
    docker \
    && yum clean all

# Install Node.js 16
RUN curl -sL https://rpm.nodesource.com/setup_16.x | bash - && \
    yum install -y nodejs

# Install Python 3.9
RUN amazon-linux-extras install python3.8 && \
    ln -s /usr/bin/python3.8 /usr/bin/python3 && \
    curl -O https://bootstrap.pypa.io/get-pip.py && \
    python3 get-pip.py

# Install specific tools
RUN npm install -g @angular/cli @ionic/cli typescript && \
    pip3 install awscli boto3 pytest

# Install kubectl
RUN curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.21.2/2021-07-05/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin

# Install Terraform
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add - && \
    yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo && \
    yum install terraform

# Create non-root user
RUN useradd -m -s /bin/bash builduser
USER builduser
WORKDIR /home/builduser

# Set environment variables
ENV PATH="/home/builduser/.local/bin:${PATH}"

# Entry point
ENTRYPOINT ["/usr/local/bin/dockerd-entrypoint.sh"]
```

**Building and Publishing Custom Image**

```bash
# Build the custom image
docker build -t my-custom-codebuild .

# Tag for ECR
docker tag my-custom-codebuild:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/my-custom-codebuild:latest

# Push to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/my-custom-codebuild:latest
```

**Using Custom Image in CodeBuild**

```json
{
  "name": "custom-build-project",
  "source": {
    "type": "CODECOMMIT",
    "location": "https://git-codecommit.region.amazonaws.com/v1/repos/my-repo"
  },
  "artifacts": {
    "type": "S3",
    "location": "my-build-artifacts"
  },
  "environment": {
    "type": "LINUX_CONTAINER",
    "image": "123456789012.dkr.ecr.us-west-2.amazonaws.com/my-custom-codebuild:latest",
    "computeType": "BUILD_GENERAL1_MEDIUM",
    "privilegedMode": true
  },
  "serviceRole": "arn:aws:iam::123456789012:role/service-role/codebuild-service-role"
}
```

### Docker-based Build Environments

CodeBuild supports running builds in Docker containers, enabling consistent build environments and advanced containerization workflows.

#### Privileged Mode for Docker Builds

```yaml
# Build project configuration
Environment:
  Type: LINUX_CONTAINER
  Image: aws/codebuild/amazonlinux2-x86_64-standard:3.0
  ComputeType: BUILD_GENERAL1_MEDIUM
  PrivilegedMode: true  # Required for Docker builds
```

#### Multi-stage Docker Build Example

```yaml
version: 0.2

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      - REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/my-app
      - IMAGE_TAG=${CODEBUILD_BUILD_NUMBER}
      
  build:
    commands:
      - echo Build started on `date`
      - echo Building Docker image...
      
      # Multi-stage build
      - |
        docker build -t $REPOSITORY_URI:$IMAGE_TAG \
          --build-arg BUILD_NUMBER=$CODEBUILD_BUILD_NUMBER \
          --build-arg COMMIT_HASH=$CODEBUILD_RESOLVED_SOURCE_VERSION \
          --target production .
          
      - docker tag $REPOSITORY_URI:$IMAGE_TAG $REPOSITORY_URI:latest
      
      # Security scanning
      - echo Running security scan...
      - docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image $REPOSITORY_URI:$IMAGE_TAG
      
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing Docker image...
      - docker push $REPOSITORY_URI:$IMAGE_TAG
      - docker push $REPOSITORY_URI:latest
      
      # Generate image definitions for ECS deployment
      - printf '[{"name":"my-app","imageUri":"%s"}]' $REPOSITORY_URI:$IMAGE_TAG > imagedefinitions.json
      
      # Clean up local images to save space
      - docker image prune -f

artifacts:
  files:
    - imagedefinitions.json
```

#### Docker Compose Integration

```yaml
version: 0.2

phases:
  install:
    commands:
      - curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
      - chmod +x /usr/local/bin/docker-compose
      
  pre_build:
    commands:
      - echo Starting services with Docker Compose...
      - docker-compose -f docker-compose.test.yml up -d database redis
      - echo Waiting for services to be ready...
      - sleep 30
      
  build:
    commands:
      - echo Running integration tests...
      - docker-compose -f docker-compose.test.yml run --rm app npm run test:integration
      
      - echo Building production image...
      - docker-compose -f docker-compose.yml build app
      
  post_build:
    commands:
      - echo Cleaning up test services...
      - docker-compose -f docker-compose.test.yml down
      
    finally:
      - docker-compose -f docker-compose.test.yml logs
```

### Environment Optimization and Performance

#### Build Performance Optimization

**Optimized Runtime Installation**

```yaml
version: 0.2

phases:
  install:
    runtime-versions:
      nodejs: 16
    commands:
      # Use specific versions for consistency
      - npm install -g npm@8.1.0 --no-audit --no-fund
      
      # Parallel downloads
      - npm config set maxsockets 15
      - npm config set network-concurrency 15
      
      # Use npm ci for faster, reliable installs
      - npm ci --production=false --silent
      
  pre_build:
    commands:
      # Warm up dependencies
      - npm run postinstall 2>/dev/null || echo "No postinstall script"
      
      # Pre-compile TypeScript if needed
      - npm run build:types 2>/dev/null || echo "No TypeScript pre-compilation"
```

**Resource Optimization**

```yaml
version: 0.2

phases:
  install:
    commands:
      # Clean package manager caches
      - npm cache clean --force
      - pip cache purge
      
      # Optimize memory usage
      - export NODE_OPTIONS="--max-old-space-size=4096"
      - export PYTHONUNBUFFERED=1
      
  build:
    commands:
      # Use all available cores for compilation
      - export MAKEFLAGS="-j$(nproc)"
      
      # Parallel test execution
      - npm run test -- --maxWorkers=$(nproc)
      
      # Memory-efficient build
      - npm run build -- --max-old-space-size=7168
```

---

## 4. Advanced Build Configurations

### Build Caching Optimization

CodeBuild supports caching to speed up builds by reusing dependencies and intermediate build artifacts between builds.

#### Local Caching

Local caching stores cache on the build host and is the fastest option for subsequent builds.

```yaml
version: 0.2

cache:
  paths:
    # Node.js dependencies
    - node_modules/**/*
    - ~/.npm/**/*
    
    # Python dependencies
    - ~/.cache/pip/**/*
    - ~/.local/lib/python*/**/*
    
    # Java dependencies
    - ~/.gradle/caches/**/*
    - ~/.m2/repository/**/*
    
    # .NET dependencies  
    - ~/.nuget/packages/**/*
    
    # Docker layers (when using privileged mode)
    - /var/lib/docker/**/*

phases:
  install:
    runtime-versions:
      nodejs: 16
    commands:
      # Leverage cached node_modules if available
      - |
        if [ -d "node_modules" ]; then
          echo "Using cached node_modules"
          npm ci --cache ~/.npm --prefer-offline --no-audit
        else
          echo "Installing dependencies from scratch"
          npm ci --cache ~/.npm
        fi

  build:
    commands:
      # Use cached Docker layers when building
      - docker build --cache-from my-app:cache -t my-app:latest .
```

#### S3 Caching

S3 caching persists cache across different build hosts and is useful for distributed teams.

```json
{
  "name": "cached-build-project",
  "cache": {
    "type": "S3",
    "location": "my-build-cache-bucket/cache"
  },
  "environment": {
    "type": "LINUX_CONTAINER",
    "image": "aws/codebuild/amazonlinux2-x86_64-standard:3.0",
    "computeType": "BUILD_GENERAL1_MEDIUM"
  }
}
```

#### Advanced Caching Strategies

```yaml
version: 0.2

env:
  variables:
    CACHE_KEY: $CODEBUILD_RESOLVED_SOURCE_VERSION

cache:
  paths:
    - node_modules/**/*
    - .gradle/caches/**/*
    - target/dependency/**/*

phases:
  install:
    commands:
      # Create cache key based on dependency files
      - DEPS_HASH=$(cat package-lock.json pom.xml | sha256sum | cut -d' ' -f1)
      - echo "Dependencies hash: $DEPS_HASH"
      
      # Check for cached dependencies
      - |
        if aws s3 cp s3://my-cache-bucket/deps-$DEPS_HASH.tar.gz /tmp/deps-cache.tar.gz; then
          echo "Restoring dependencies from cache"
          tar -xzf /tmp/deps-cache.tar.gz
        else
          echo "No cache found, installing dependencies"
          npm ci
          mvn dependency:resolve
          
          # Create cache for next build
          tar -czf /tmp/deps-cache.tar.gz node_modules .m2/repository
          aws s3 cp /tmp/deps-cache.tar.gz s3://my-cache-bucket/deps-$DEPS_HASH.tar.gz
        fi

  build:
    commands:
      # Use cached build artifacts if source hasn't changed
      - SOURCE_HASH=$(find src -type f -exec sha256sum {} \; | sha256sum | cut -d' ' -f1)
      - echo "Source hash: $SOURCE_HASH"
      
      - |
        if aws s3 cp s3://my-cache-bucket/build-$SOURCE_HASH.tar.gz /tmp/build-cache.tar.gz; then
          echo "Restoring build from cache"
          tar -xzf /tmp/build-cache.tar.gz
        else
          echo "No build cache found, building from source"
          npm run build
          mvn compile
          
          # Cache build results
          tar -czf /tmp/build-cache.tar.gz dist target/classes
          aws s3 cp /tmp/build-cache.tar.gz s3://my-cache-bucket/build-$SOURCE_HASH.tar.gz
        fi
```

### Parallel Build Execution

#### Batch Builds

Batch builds allow running multiple related builds in parallel or in a specific sequence.

```json
{
  "projectName": "parallel-build-project",
  "buildBatchConfig": {
    "serviceRole": "arn:aws:iam::account:role/service-role/codebuild-batch-service-role",
    "restrictions": {
      "maximumBuildsAllowed": 10,
      "computeTypesAllowed": ["BUILD_GENERAL1_SMALL", "BUILD_GENERAL1_MEDIUM"]
    },
    "timeoutInMinutes": 60,
    "batchReportMode": "REPORT_INDIVIDUAL_BUILDS"
  }
}
```

**Buildspec for Batch Builds**

```yaml
version: 0.2

batch:
  fast-fail: false
  build-list:
    - identifier: unit-tests
      env:
        variables:
          TEST_TYPE: unit
    - identifier: integration-tests
      env:
        variables:
          TEST_TYPE: integration
    - identifier: security-scan
      env:
        variables:
          SCAN_TYPE: security
      depends-on:
        - unit-tests
    - identifier: performance-tests
      env:
        variables:
          TEST_TYPE: performance
      depends-on:
        - unit-tests
        - integration-tests

phases:
  install:
    runtime-versions:
      nodejs: 16
      
  pre_build:
    commands:
      - npm ci
      
  build:
    commands:
      - |
        case $TEST_TYPE in
          unit)
            echo "Running unit tests"
            npm run test:unit -- --coverage
            ;;
          integration)
            echo "Running integration tests"
            npm run test:integration
            ;;
          performance)
            echo "Running performance tests"
            npm run test:performance
            ;;
          *)
            echo "Running security scan"
            npm audit
            npm run security:scan
            ;;
        esac
```

#### Matrix Builds

Matrix builds test multiple configurations simultaneously.

```yaml
version: 0.2

batch:
  build-matrix:
    static:
      env:
        variables:
          NODE_ENV: production
    dynamic:
      env:
        variables:
          NODE_VERSION:
            - "14"
            - "16"
            - "18"
          PLATFORM:
            - "linux"
            - "windows"

phases:
  install:
    runtime-versions:
      nodejs: $NODE_VERSION
    commands:
      - echo "Building with Node.js $NODE_VERSION on $PLATFORM"
      
  build:
    commands:
      - npm ci
      - npm run build
      - npm run test
      
artifacts:
  files:
    - dist/**/*
  name: app-$PLATFORM-node$NODE_VERSION-$CODEBUILD_BUILD_NUMBER
```

### Conditional Build Logic

#### Advanced Conditional Execution

```yaml
version: 0.2

env:
  variables:
    SHOULD_DEPLOY: "false"
    RUN_E2E_TESTS: "false"

phases:
  install:
    runtime-versions:
      nodejs: 16
    commands:
      - npm ci
      
  pre_build:
    commands:
      # Determine build strategy based on branch and changes
      - |
        echo "Analyzing build requirements..."
        
        # Check if this is a release branch
        if [[ "$CODEBUILD_WEBHOOK_HEAD_REF" =~ ^refs/heads/(main|release/.+)$ ]]; then
          export SHOULD_DEPLOY="true"
          export RUN_E2E_TESTS="true"
          echo "Release build detected - enabling deployment and E2E tests"
        fi
        
        # Check for infrastructure changes
        if git diff --name-only HEAD~1 | grep -E "(infrastructure/|terraform/|cloudformation/)"; then
          export VALIDATE_INFRASTRUCTURE="true"
          echo "Infrastructure changes detected - enabling validation"
        fi
        
        # Check for dependency changes
        if git diff --name-only HEAD~1 | grep -E "(package-lock.json|requirements.txt|pom.xml)"; then
          export SECURITY_SCAN="true"
          echo "Dependency changes detected - enabling security scan"
        fi

  build:
    commands:
      - echo "Building application..."
      - npm run build
      
      # Conditional infrastructure validation
      - |
        if [ "$VALIDATE_INFRASTRUCTURE" = "true" ]; then
          echo "Validating infrastructure changes..."
          cd infrastructure
          terraform init
          terraform validate
          terraform plan -out=tfplan
          cd ..
        fi
      
      # Conditional security scanning
      - |
        if [ "$SECURITY_SCAN" = "true" ]; then
          echo "Running security scan..."
          npm audit --audit-level moderate
          snyk test --severity-threshold=medium
        fi

  post_build:
    commands:
      # Conditional E2E testing
      - |
        if [ "$RUN_E2E_TESTS" = "true" ]; then
          echo "Running E2E tests..."
          npm run test:e2e
        fi
      
      # Conditional deployment preparation
      - |
        if [ "$SHOULD_DEPLOY" = "true" ]; then
          echo "Preparing deployment artifacts..."
          aws s3 sync dist/ s3://deployment-bucket/builds/$CODEBUILD_BUILD_NUMBER/
          
          # Update deployment configuration
          cat > deployment-config.json << EOF
          {
            "buildNumber": "$CODEBUILD_BUILD_NUMBER",
            "sourceVersion": "$CODEBUILD_RESOLVED_SOURCE_VERSION",
            "deploymentBucket": "deployment-bucket",
            "deploymentPath": "builds/$CODEBUILD_BUILD_NUMBER/",
            "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
          }
          EOF
        fi

artifacts:
  files:
    - dist/**/*
    - deployment-config.json
    - infrastructure/tfplan
  exclude-paths:
    - node_modules/**/*
    - '**/*.test.js'
```

#### Feature Flag Integration

```yaml
version: 0.2

env:
  parameter-store:
    FEATURE_FLAGS: /myapp/build/feature-flags
    
phases:
  pre_build:
    commands:
      # Parse feature flags
      - |
        echo "Loading feature flags..."
        FLAGS=$(echo $FEATURE_FLAGS | jq -r .)
        
        export ENABLE_ANALYTICS=$(echo $FLAGS | jq -r '.analytics // false')
        export ENABLE_EXPERIMENTS=$(echo $FLAGS | jq -r '.experiments // false')
        export ENABLE_ADVANCED_LOGGING=$(echo $FLAGS | jq -r '.advancedLogging // false')
        
        echo "Feature flags loaded:"
        echo "  Analytics: $ENABLE_ANALYTICS"
        echo "  Experiments: $ENABLE_EXPERIMENTS" 
        echo "  Advanced Logging: $ENABLE_ADVANCED_LOGGING"

  build:
    commands:
      # Build with feature flags
      - |
        BUILD_ARGS=""
        if [ "$ENABLE_ANALYTICS" = "true" ]; then
          BUILD_ARGS="$BUILD_ARGS --define ANALYTICS=true"
        fi
        if [ "$ENABLE_EXPERIMENTS" = "true" ]; then
          BUILD_ARGS="$BUILD_ARGS --define EXPERIMENTS=true"
        fi
        if [ "$ENABLE_ADVANCED_LOGGING" = "true" ]; then
          BUILD_ARGS="$BUILD_ARGS --define ADVANCED_LOGGING=true"
        fi
        
        npm run build -- $BUILD_ARGS
        
      # Conditional test suites based on features
      - |
        if [ "$ENABLE_ANALYTICS" = "true" ]; then
          npm run test:analytics
        fi
        if [ "$ENABLE_EXPERIMENTS" = "true" ]; then
          npm run test:experiments
        fi
```

---

## 5. Security and Compliance

### IAM Roles and Policies

CodeBuild uses service roles to access AWS services on your behalf during builds. Proper IAM configuration is crucial for security and functionality.

#### Service Role Configuration

**Basic CodeBuild Service Role**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Comprehensive Service Role Policy**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream", 
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::my-source-bucket/*",
        "arn:aws:s3:::my-artifacts-bucket/*",
        "arn:aws:s3:::my-cache-bucket/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codecommit:GitPull"
      ],
      "Resource": "arn:aws:codecommit:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/myapp/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:myapp/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey"
      ],
      "Resource": "arn:aws:kms:*:*:key/*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": [
            "s3.*.amazonaws.com",
            "secretsmanager.*.amazonaws.com",
            "ssm.*.amazonaws.com"
          ]
        }
      }
    }
  ]
}
```

#### Principle of Least Privilege

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LoggingPermissions",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:logs:us-west-2:123456789012:log-group:/aws/codebuild/my-project",
        "arn:aws:logs:us-west-2:123456789012:log-group:/aws/codebuild/my-project:*"
      ]
    },
    {
      "Sid": "SourceAccess",
      "Effect": "Allow",
      "Action": [
        "codecommit:GitPull"
      ],
      "Resource": "arn:aws:codecommit:us-west-2:123456789012:my-specific-repo",
      "Condition": {
        "StringEquals": {
          "codecommit:ExistingObjectAttributes/branch": ["main", "develop"]
        }
      }
    },
    {
      "Sid": "ArtifactAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::my-build-artifacts/my-project/*"
    },
    {
      "Sid": "ParameterStoreAccess",
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter"
      ],
      "Resource": [
        "arn:aws:ssm:us-west-2:123456789012:parameter/myapp/build/*"
      ]
    }
  ]
}
```

### VPC Configuration for Private Builds

When builds need to access private resources, you can configure CodeBuild to run within a VPC.

#### VPC Configuration

```json
{
  "projectName": "private-build-project",
  "vpcConfig": {
    "vpcId": "vpc-12345678",
    "subnets": [
      "subnet-12345678",
      "subnet-87654321"
    ],
    "securityGroupIds": [
      "sg-12345678"
    ]
  }
}
```

#### Security Group Configuration

```json
{
  "GroupDescription": "Security group for CodeBuild VPC builds",
  "GroupName": "codebuild-vpc-sg",
  "VpcId": "vpc-12345678",
  "SecurityGroupRules": [
    {
      "IpProtocol": "tcp",
      "FromPort": 443,
      "ToPort": 443,
      "CidrIp": "0.0.0.0/0",
      "Description": "HTTPS outbound for package downloads"
    },
    {
      "IpProtocol": "tcp",
      "FromPort": 80,
      "ToPort": 80,
      "CidrIp": "0.0.0.0/0", 
      "Description": "HTTP outbound for package downloads"
    },
    {
      "IpProtocol": "tcp",
      "FromPort": 3306,
      "ToPort": 3306,
      "SourceSecurityGroupId": "sg-database",
      "Description": "MySQL access to RDS"
    },
    {
      "IpProtocol": "tcp",
      "FromPort": 6379,
      "ToPort": 6379,
      "SourceSecurityGroupId": "sg-redis",
      "Description": "Redis access to ElastiCache"
    }
  ]
}
```

#### VPC Buildspec with Private Resource Access

```yaml
version: 0.2

env:
  variables:
    DATABASE_HOST: db.internal.example.com
    REDIS_HOST: redis.internal.example.com
    
phases:
  pre_build:
    commands:
      # Test private resource connectivity
      - nc -zv $DATABASE_HOST 3306
      - nc -zv $REDIS_HOST 6379
      
      # Configure application for VPC environment
      - export DATABASE_URL="mysql://user:pass@$DATABASE_HOST:3306/testdb"
      - export REDIS_URL="redis://$REDIS_HOST:6379"
      
  build:
    commands:
      # Run integration tests against private resources
      - npm run test:integration
      
      # Build application with VPC configuration
      - npm run build:vpc
```

### Secrets and Credentials Management

#### Using AWS Secrets Manager

```yaml
version: 0.2

env:
  secrets-manager:
    DATABASE_PASSWORD: prod/myapp/database:password
    API_KEY: prod/myapp/external:api_key
    SIGNING_KEY: prod/myapp/auth:signing_key
    
phases:
  pre_build:
    commands:
      # Verify secrets are loaded
      - echo "Database password loaded: $([ -n "$DATABASE_PASSWORD" ] && echo "✓" || echo "✗")"
      - echo "API key loaded: $([ -n "$API_KEY" ] && echo "✓" || echo "✗")"
      
      # Use secrets in configuration
      - |
        cat > .env.production << EOF
        DATABASE_URL=postgresql://user:$DATABASE_PASSWORD@db.example.com:5432/app
        EXTERNAL_API_KEY=$API_KEY
        JWT_SIGNING_KEY=$SIGNING_KEY
        EOF
      
  build:
    commands:
      - npm run build:production
      
  post_build:
    commands:
      # Clean up sensitive files
      - rm -f .env.production
      - unset DATABASE_PASSWORD API_KEY SIGNING_KEY
```

#### Using Systems Manager Parameter Store

```yaml
version: 0.2

env:
  parameter-store:
    BUILD_CONFIG: /myapp/build/config
    DEPLOYMENT_TARGETS: /myapp/deployment/targets
    FEATURE_FLAGS: /myapp/features/flags
    
phases:
  pre_build:
    commands:
      # Parse configuration parameters
      - |
        echo "Loading build configuration..."
        echo $BUILD_CONFIG | jq -r '.compiler.target' > TARGET_ENV
        echo $BUILD_CONFIG | jq -r '.optimization.level' > OPT_LEVEL
        
        echo "Target environment: $(cat TARGET_ENV)"
        echo "Optimization level: $(cat OPT_LEVEL)"
      
      # Configure deployment targets
      - |
        echo "Configuring deployment targets..."
        TARGETS=$(echo $DEPLOYMENT_TARGETS | jq -r '.environments[]')
        echo "Deployment targets: $TARGETS"
        
  build:
    commands:
      - npm run build -- --target=$(cat TARGET_ENV) --optimization=$(cat OPT_LEVEL)
```

### Build Artifact Encryption

#### S3 Artifact Encryption

```json
{
  "artifacts": {
    "type": "S3",
    "location": "my-build-artifacts/encrypted",
    "encryptionDisabled": false,
    "overrideArtifactName": true,
    "name": "secure-build-$CODEBUILD_BUILD_NUMBER",
    "packaging": "ZIP"
  },
  "secondaryArtifacts": [
    {
      "type": "S3", 
      "location": "my-secure-reports/coverage",
      "artifactIdentifier": "coverage-reports",
      "encryptionDisabled": false,
      "name": "coverage-$CODEBUILD_BUILD_NUMBER"
    }
  ]
}
```

#### KMS Encryption Configuration

```json
{
  "encryptionKey": "arn:aws:kms:us-west-2:123456789012:key/12345678-1234-1234-1234-123456789012",
  "artifacts": {
    "type": "S3",
    "location": "my-encrypted-artifacts",
    "encryptionDisabled": false
  },
  "cache": {
    "type": "S3", 
    "location": "my-encrypted-cache"
  }
}
```

#### Buildspec with Encryption

```yaml
version: 0.2

phases:
  pre_build:
    commands:
      # Encrypt sensitive build files
      - aws kms encrypt --key-id $KMS_KEY_ID --plaintext file://config/secrets.json --output text --query CiphertextBlob | base64 -d > config/secrets.encrypted
      
  build:
    commands:
      - npm run build
      
      # Encrypt build logs before upload
      - |
        if [ -f build.log ]; then
          aws kms encrypt --key-id $KMS_KEY_ID --plaintext file://build.log --output text --query CiphertextBlob | base64 -d > build.log.encrypted
        fi
      
  post_build:
    commands:
      # Encrypt final artifacts
      - tar czf artifacts.tar.gz dist/
      - aws kms encrypt --key-id $KMS_KEY_ID --plaintext file://artifacts.tar.gz --output text --query CiphertextBlob | base64 -d > artifacts.encrypted

artifacts:
  files:
    - artifacts.encrypted
    - build.log.encrypted
```

### Compliance and Audit

#### Comprehensive Audit Logging

```yaml
version: 0.2

env:
  variables:
    AUDIT_BUCKET: compliance-audit-logs
    COMPLIANCE_LEVEL: SOX
    
phases:
  install:
    commands:
      # Log build start with compliance metadata
      - |
        cat > build-audit.json << EOF
        {
          "buildId": "$CODEBUILD_BUILD_ID",
          "buildNumber": "$CODEBUILD_BUILD_NUMBER", 
          "sourceVersion": "$CODEBUILD_RESOLVED_SOURCE_VERSION",
          "initiatedBy": "$CODEBUILD_INITIATOR",
          "startTime": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
          "complianceLevel": "$COMPLIANCE_LEVEL",
          "projectName": "$CODEBUILD_BUILD_IMAGE"
        }
        EOF
        
        aws s3 cp build-audit.json s3://$AUDIT_BUCKET/builds/$CODEBUILD_BUILD_ID/start.json

  pre_build:
    commands:
      # Audit dependency installation
      - npm audit --audit-level moderate --json > security-audit.json
      - aws s3 cp security-audit.json s3://$AUDIT_BUCKET/builds/$CODEBUILD_BUILD_ID/
      
      # Compliance checks
      - |
        echo "Running compliance checks..."
        if [ "$COMPLIANCE_LEVEL" = "SOX" ]; then
          # SOX compliance checks
          npm run compliance:sox
        elif [ "$COMPLIANCE_LEVEL" = "PCI" ]; then
          # PCI compliance checks
          npm run compliance:pci
        fi

  build:
    commands:
      # Log build process
      - npm run build 2>&1 | tee build-output.log
      
      # Generate SBOM (Software Bill of Materials)
      - npm run generate:sbom > sbom.json
      - aws s3 cp sbom.json s3://$AUDIT_BUCKET/builds/$CODEBUILD_BUILD_ID/

  post_build:
    commands:
      # Final compliance validation
      - npm run validate:compliance
      
      # Upload all audit logs
      - aws s3 cp build-output.log s3://$AUDIT_BUCKET/builds/$CODEBUILD_BUILD_ID/
      
      # Create compliance report
      - |
        cat > compliance-report.json << EOF
        {
          "buildId": "$CODEBUILD_BUILD_ID",
          "complianceLevel": "$COMPLIANCE_LEVEL",
          "endTime": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
          "buildStatus": "$CODEBUILD_BUILD_SUCCEEDING",
          "securityScanPassed": true,
          "dependencyAuditPassed": true,
          "complianceTestsPassed": true
        }
        EOF
        
        aws s3 cp compliance-report.json s3://$AUDIT_BUCKET/builds/$CODEBUILD_BUILD_ID/final.json

    finally:
      # Always log build completion
      - |
        cat > build-completion.json << EOF
        {
          "buildId": "$CODEBUILD_BUILD_ID",
          "finalStatus": "$([ "$CODEBUILD_BUILD_SUCCEEDING" = "1" ] && echo "SUCCESS" || echo "FAILED")",
          "completionTime": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        }
        EOF
        
        aws s3 cp build-completion.json s3://$AUDIT_BUCKET/builds/$CODEBUILD_BUILD_ID/completion.json
```

---

## 6. Integration Patterns

### CodeCommit Integration

CodeBuild integrates seamlessly with CodeCommit for source code management and automated build triggers.

#### Webhook-based Triggers

```json
{
  "name": "codecommit-webhook-build",
  "source": {
    "type": "CODECOMMIT",
    "location": "https://git-codecommit.us-west-2.amazonaws.com/v1/repos/my-app",
    "webhook": {
      "filterGroups": [
        [
          {
            "type": "EVENT", 
            "pattern": "PUSH"
          },
          {
            "type": "HEAD_REF",
            "pattern": "^refs/heads/(main|develop)$"
          }
        ],
        [
          {
            "type": "EVENT",
            "pattern": "PULL_REQUEST_CREATED,PULL_REQUEST_UPDATED"
          },
          {
            "type": "BASE_REF", 
            "pattern": "^refs/heads/main$"
          }
        ]
      ]
    }
  }
}
```

#### Branch-specific Build Configuration

```yaml
version: 0.2

phases:
  install:
    runtime-versions:
      nodejs: 16
      
  pre_build:
    commands:
      # Configure build based on branch
      - |
        BRANCH_NAME=${CODEBUILD_WEBHOOK_HEAD_REF#refs/heads/}
        echo "Building branch: $BRANCH_NAME"
        
        case $BRANCH_NAME in
          main)
            export BUILD_ENV=production
            export RUN_FULL_TESTS=true
            export DEPLOY_ENABLED=true
            ;;
          develop)
            export BUILD_ENV=staging
            export RUN_FULL_TESTS=true
            export DEPLOY_ENABLED=true
            ;;
          feature/*)
            export BUILD_ENV=development
            export RUN_FULL_TESTS=false
            export DEPLOY_ENABLED=false
            ;;
          *)
            export BUILD_ENV=development
            export RUN_FULL_TESTS=false
            export DEPLOY_ENABLED=false
            ;;
        esac
        
        echo "Build environment: $BUILD_ENV"
        echo "Full tests: $RUN_FULL_TESTS"
        echo "Deploy enabled: $DEPLOY_ENABLED"

  build:
    commands:
      - npm run build:$BUILD_ENV
      
      # Conditional testing
      - |
        if [ "$RUN_FULL_TESTS" = "true" ]; then
          npm run test:all
        else
          npm run test:unit
        fi

  post_build:
    commands:
      # Conditional deployment preparation
      - |
        if [ "$DEPLOY_ENABLED" = "true" ]; then
          echo "Preparing deployment for $BUILD_ENV"
          aws s3 sync dist/ s3://deployments-$BUILD_ENV/
          
          # Trigger deployment pipeline
          aws codepipeline start-pipeline-execution \
            --name "deploy-$BUILD_ENV-pipeline"
        fi
```

### CodePipeline Integration

CodeBuild is commonly used as build and test actions within CodePipeline workflows.

#### Pipeline Integration Configuration

```json
{
  "Name": "MyPipeline",
  "RoleArn": "arn:aws:iam::account:role/service-role/AWSCodePipelineRole",
  "ArtifactStore": {
    "Type": "S3",
    "Location": "my-pipeline-artifacts"
  },
  "Stages": [
    {
      "Name": "Source",
      "Actions": [
        {
          "Name": "Source",
          "ActionTypeId": {
            "Category": "Source",
            "Owner": "AWS",
            "Provider": "CodeCommit",
            "Version": "1"
          },
          "Configuration": {
            "RepositoryName": "my-app",
            "BranchName": "main"
          },
          "OutputArtifacts": [
            {
              "Name": "SourceOutput"
            }
          ]
        }
      ]
    },
    {
      "Name": "Build",
      "Actions": [
        {
          "Name": "Build",
          "ActionTypeId": {
            "Category": "Build",
            "Owner": "AWS", 
            "Provider": "CodeBuild",
            "Version": "1"
          },
          "Configuration": {
            "ProjectName": "my-build-project"
          },
          "InputArtifacts": [
            {
              "Name": "SourceOutput"
            }
          ],
          "OutputArtifacts": [
            {
              "Name": "BuildOutput"
            }
          ]
        }
      ]
    },
    {
      "Name": "Test",
      "Actions": [
        {
          "Name": "UnitTest",
          "ActionTypeId": {
            "Category": "Test",
            "Owner": "AWS",
            "Provider": "CodeBuild", 
            "Version": "1"
          },
          "Configuration": {
            "ProjectName": "my-test-project"
          },
          "InputArtifacts": [
            {
              "Name": "SourceOutput"
            }
          ],
          "RunOrder": 1
        },
        {
          "Name": "IntegrationTest",
          "ActionTypeId": {
            "Category": "Test",
            "Owner": "AWS",
            "Provider": "CodeBuild",
            "Version": "1"
          },
          "Configuration": {
            "ProjectName": "my-integration-test-project"
          },
          "InputArtifacts": [
            {
              "Name": "BuildOutput"
            }
          ],
          "RunOrder": 2
        }
      ]
    }
  ]
}
```

#### Multi-Stage Pipeline Build

```yaml
# Build stage buildspec
version: 0.2

phases:
  install:
    runtime-versions:
      nodejs: 16
      
  pre_build:
    commands:
      - npm ci
      
  build:
    commands:
      - npm run build
      - npm run test:unit

artifacts:
  files:
    - dist/**/*
    - package.json
    - buildspec-test.yml
  name: build-artifacts

---
# Test stage buildspec (buildspec-test.yml)
version: 0.2

phases:
  install:
    runtime-versions:
      nodejs: 16
      
  pre_build:
    commands:
      - npm ci --production=false
      
  build:
    commands:
      - npm run test:integration
      - npm run test:e2e

artifacts:
  files:
    - test-results/**/*
  name: test-results
```

### Third-party Source Integration

#### GitHub Integration

```json
{
  "name": "github-integration-build",
  "source": {
    "type": "GITHUB",
    "location": "https://github.com/myorg/myapp",
    "auth": {
      "type": "OAUTH",
      "resource": "arn:aws:codebuild:us-west-2:account:token/github"
    },
    "webhook": {
      "filterGroups": [
        [
          {
            "type": "EVENT",
            "pattern": "PUSH"
          },
          {
            "type": "HEAD_REF", 
            "pattern": "^refs/heads/main$"
          }
        ],
        [
          {
            "type": "EVENT",
            "pattern": "PULL_REQUEST_OPENED,PULL_REQUEST_UPDATED"
          }
        ]
      ]
    },
    "reportBuildStatus": true,
    "buildStatusConfig": {
      "context": "AWS CodeBuild",
      "targetUrl": "https://console.aws.amazon.com/codesuite/codebuild/projects/my-project/history"
    }
  }
}
```

#### Bitbucket Integration

```json
{
  "name": "bitbucket-integration-build",
  "source": {
    "type": "BITBUCKET",
    "location": "https://bitbucket.org/myorg/myapp",
    "auth": {
      "type": "OAUTH",
      "resource": "arn:aws:codebuild:us-west-2:account:token/bitbucket"
    },
    "webhook": {
      "filterGroups": [
        [
          {
            "type": "EVENT",
            "pattern": "PUSH"
          }
        ]
      ]
    }
  }
}
```

### Container Registry Integration

#### ECR Integration for Build Images

```yaml
version: 0.2

phases:
  pre_build:
    commands:
      # Login to ECR for custom build tools
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      
      # Pull custom build tools
      - docker pull $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/build-tools:latest
      
  build:
    commands:
      # Use custom build tools in container
      - |
        docker run --rm \
          -v $(pwd):/workspace \
          -w /workspace \
          $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/build-tools:latest \
          ./custom-build-script.sh
      
      # Build application container
      - docker build -t my-app:$CODEBUILD_BUILD_NUMBER .
      - docker tag my-app:$CODEBUILD_BUILD_NUMBER $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/my-app:$CODEBUILD_BUILD_NUMBER
      - docker tag my-app:$CODEBUILD_BUILD_NUMBER $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/my-app:latest

  post_build:
    commands:
      # Push to ECR
      - docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/my-app:$CODEBUILD_BUILD_NUMBER
      - docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/my-app:latest
```

#### Multi-Registry Support

```yaml
version: 0.2

env:
  variables:
    ECR_REPOSITORY_URI: 123456789012.dkr.ecr.us-west-2.amazonaws.com/my-app
    DOCKER_HUB_REPOSITORY: myorg/my-app
    
  secrets-manager:
    DOCKER_HUB_USERNAME: prod/docker:username
    DOCKER_HUB_TOKEN: prod/docker:token

phases:
  pre_build:
    commands:
      # Login to multiple registries
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ECR_REPOSITORY_URI
      
      - echo Logging in to Docker Hub...
      - echo $DOCKER_HUB_TOKEN | docker login --username $DOCKER_HUB_USERNAME --password-stdin
      
  build:
    commands:
      - docker build -t my-app:$CODEBUILD_BUILD_NUMBER .
      
      # Tag for multiple registries
      - docker tag my-app:$CODEBUILD_BUILD_NUMBER $ECR_REPOSITORY_URI:$CODEBUILD_BUILD_NUMBER
      - docker tag my-app:$CODEBUILD_BUILD_NUMBER $ECR_REPOSITORY_URI:latest
      - docker tag my-app:$CODEBUILD_BUILD_NUMBER $DOCKER_HUB_REPOSITORY:$CODEBUILD_BUILD_NUMBER
      - docker tag my-app:$CODEBUILD_BUILD_NUMBER $DOCKER_HUB_REPOSITORY:latest

  post_build:
    commands:
      # Push to ECR
      - docker push $ECR_REPOSITORY_URI:$CODEBUILD_BUILD_NUMBER
      - docker push $ECR_REPOSITORY_URI:latest
      
      # Push to Docker Hub
      - docker push $DOCKER_HUB_REPOSITORY:$CODEBUILD_BUILD_NUMBER
      - docker push $DOCKER_HUB_REPOSITORY:latest
```

---

## 7. Monitoring and Observability

### CloudWatch Metrics and Monitoring

CodeBuild provides built-in CloudWatch metrics and supports custom metrics for comprehensive build monitoring.

#### Built-in Metrics

CodeBuild automatically publishes the following metrics to CloudWatch:

- **Builds**: Number of builds triggered
- **Duration**: Build duration in minutes
- **SucceededBuilds**: Number of successful builds  
- **FailedBuilds**: Number of failed builds
- **DownloadSourceDuration**: Time to download source
- **SubmittedBuilds**: Number of submitted builds

#### Custom Metrics Implementation

```yaml
version: 0.2

phases:
  install:
    commands:
      # Install CloudWatch agent
      - wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
      - rpm -U ./amazon-cloudwatch-agent.rpm

  pre_build:
    commands:
      # Record custom metrics
      - |
        aws cloudwatch put-metric-data \
          --namespace "CodeBuild/CustomMetrics" \
          --metric-data MetricName=DependencyInstallStart,Value=1,Unit=Count \
                       Dimensions=[{Name=ProjectName,Value=$CODEBUILD_PROJECT_NAME},{Name=BuildId,Value=$CODEBUILD_BUILD_ID}]
      
      # Start timing dependency installation
      - DEPS_START_TIME=$(date +%s)
      - npm ci
      - DEPS_END_TIME=$(date +%s)
      - DEPS_DURATION=$((DEPS_END_TIME - DEPS_START_TIME))
      
      # Record dependency installation time
      - |
        aws cloudwatch put-metric-data \
          --namespace "CodeBuild/CustomMetrics" \
          --metric-data MetricName=DependencyInstallDuration,Value=$DEPS_DURATION,Unit=Seconds \
                       Dimensions=[{Name=ProjectName,Value=$CODEBUILD_PROJECT_NAME}]

  build:
    commands:
      # Record build phase metrics
      - BUILD_START_TIME=$(date +%s)
      
      # Count lines of code
      - LOC=$(find src -name "*.js" -o -name "*.ts" | xargs wc -l | tail -n1 | awk '{print $1}')
      - |
        aws cloudwatch put-metric-data \
          --namespace "CodeBuild/CustomMetrics" \
          --metric-data MetricName=LinesOfCode,Value=$LOC,Unit=Count \
                       Dimensions=[{Name=ProjectName,Value=$CODEBUILD_PROJECT_NAME}]
      
      # Run build
      - npm run build
      
      # Calculate and record build time
      - BUILD_END_TIME=$(date +%s)
      - BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))
      - |
        aws cloudwatch put-metric-data \
          --namespace "CodeBuild/CustomMetrics" \
          --metric-data MetricName=CompilationDuration,Value=$BUILD_DURATION,Unit=Seconds \
                       Dimensions=[{Name=ProjectName,Value=$CODEBUILD_PROJECT_NAME}]

  post_build:
    commands:
      # Test coverage metrics
      - |
        if [ -f coverage/coverage-summary.json ]; then
          COVERAGE=$(cat coverage/coverage-summary.json | jq '.total.lines.pct')
          aws cloudwatch put-metric-data \
            --namespace "CodeBuild/CustomMetrics" \
            --metric-data MetricName=TestCoverage,Value=$COVERAGE,Unit=Percent \
                         Dimensions=[{Name=ProjectName,Value=$CODEBUILD_PROJECT_NAME}]
        fi
      
      # Bundle size metrics
      - |
        if [ -f dist/main.js ]; then
          BUNDLE_SIZE=$(stat -f%z dist/main.js)
          aws cloudwatch put-metric-data \
            --namespace "CodeBuild/CustomMetrics" \
            --metric-data MetricName=BundleSize,Value=$BUNDLE_SIZE,Unit=Bytes \
                         Dimensions=[{Name=ProjectName,Value=$CODEBUILD_PROJECT_NAME}]
        fi
      
      # Success/failure metrics
      - |
        if [ "$CODEBUILD_BUILD_SUCCEEDING" = "1" ]; then
          RESULT_VALUE=1
          RESULT_METRIC="BuildSuccess"
        else
          RESULT_VALUE=0
          RESULT_METRIC="BuildFailure"
        fi
        
        aws cloudwatch put-metric-data \
          --namespace "CodeBuild/CustomMetrics" \
          --metric-data MetricName=$RESULT_METRIC,Value=$RESULT_VALUE,Unit=Count \
                       Dimensions=[{Name=ProjectName,Value=$CODEBUILD_PROJECT_NAME}]
```

#### CloudWatch Alarms Configuration

```json
{
  "AlarmName": "CodeBuild-HighFailureRate",
  "AlarmDescription": "Alert when build failure rate exceeds 25%",
  "MetricName": "FailedBuilds",
  "Namespace": "AWS/CodeBuild",
  "Statistic": "Sum",
  "Period": 300,
  "EvaluationPeriods": 2,
  "Threshold": 2,
  "ComparisonOperator": "GreaterThanThreshold",
  "Dimensions": [
    {
      "Name": "ProjectName",
      "Value": "my-build-project"
    }
  ],
  "AlarmActions": [
    "arn:aws:sns:us-west-2:123456789012:build-alerts"
  ]
}
```

### Build Log Analysis and Troubleshooting

#### Structured Logging

```yaml
version: 0.2

phases:
  install:
    commands:
      # Install log analysis tools
      - pip install structlog colorlog
      
      # Create structured logging function
      - |
        log_structured() {
          echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"level\":\"$1\",\"phase\":\"$2\",\"message\":\"$3\",\"build_id\":\"$CODEBUILD_BUILD_ID\"}"
        }
      
      - log_structured "INFO" "install" "Starting dependency installation"
      - npm ci
      - log_structured "INFO" "install" "Dependencies installed successfully"

  pre_build:
    commands:
      - log_structured "INFO" "pre_build" "Starting pre-build phase"
      
      # Log environment information
      - |
        log_structured "INFO" "pre_build" "Environment info: Node $(node --version), NPM $(npm --version)"
        log_structured "INFO" "pre_build" "Build image: $CODEBUILD_BUILD_IMAGE"
        log_structured "INFO" "pre_build" "Compute type: $CODEBUILD_COMPUTE_TYPE"
      
      # Run linting with structured output
      - |
        if npm run lint 2>&1 | tee lint-output.log; then
          log_structured "INFO" "pre_build" "Linting passed"
        else
          log_structured "ERROR" "pre_build" "Linting failed"
          cat lint-output.log | while read line; do
            log_structured "ERROR" "pre_build" "Lint error: $line"
          done
        fi

  build:
    commands:
      - log_structured "INFO" "build" "Starting build phase"
      
      # Build with progress logging
      - |
        npm run build 2>&1 | while read line; do
          log_structured "INFO" "build" "Build output: $line"
        done
      
      - log_structured "INFO" "build" "Build phase completed"

  post_build:
    commands:
      - |
        if [ "$CODEBUILD_BUILD_SUCCEEDING" = "1" ]; then
          log_structured "INFO" "post_build" "Build succeeded"
        else
          log_structured "ERROR" "post_build" "Build failed"
        fi
      
    finally:
      # Always log final status
      - |
        log_structured "INFO" "post_build" "Build finished with status: $([ "$CODEBUILD_BUILD_SUCCEEDING" = "1" ] && echo "SUCCESS" || echo "FAILURE")"
```

#### Log Aggregation and Analysis

```yaml
version: 0.2

phases:
  install:
    commands:
      # Install log shipping tools
      - curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.15.0-linux-x86_64.tar.gz
      - tar xzvf filebeat-7.15.0-linux-x86_64.tar.gz
      
  pre_build:
    commands:
      # Configure log shipping to ELK stack
      - |
        cat > filebeat.yml << EOF
        filebeat.inputs:
        - type: log
          enabled: true
          paths:
            - /codebuild/output/tmp/*.log
          fields:
            build_id: $CODEBUILD_BUILD_ID
            project_name: $CODEBUILD_PROJECT_NAME
            source_version: $CODEBUILD_RESOLVED_SOURCE_VERSION
            
        output.elasticsearch:
          hosts: ["elasticsearch.internal.example.com:9200"]
          index: "codebuild-logs-%{+yyyy.MM.dd}"
        EOF
      
      # Start background log shipping
      - ./filebeat-7.15.0-linux-x86_64/filebeat -c filebeat.yml &

  build:
    commands:
      # Build with comprehensive logging
      - npm run build 2>&1 | tee /codebuild/output/tmp/build.log
      - npm run test 2>&1 | tee /codebuild/output/tmp/test.log

  post_build:
    commands:
      # Generate build report
      - |
        cat > /codebuild/output/tmp/build-report.json << EOF
        {
          "build_id": "$CODEBUILD_BUILD_ID",
          "project_name": "$CODEBUILD_PROJECT_NAME", 
          "source_version": "$CODEBUILD_RESOLVED_SOURCE_VERSION",
          "build_status": "$([ "$CODEBUILD_BUILD_SUCCEEDING" = "1" ] && echo "SUCCESS" || echo "FAILURE")",
          "start_time": "$CODEBUILD_START_TIME",
          "end_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
          "logs": {
            "build_log": "/tmp/build.log",
            "test_log": "/tmp/test.log"
          }
        }
        EOF
      
      # Ship final logs
      - sleep 10  # Allow filebeat to ship remaining logs
      
    finally:
      # Ensure all logs are shipped
      - pkill filebeat || true
```

### Performance Monitoring and Optimization

#### Build Performance Analysis

```yaml
version: 0.2

phases:
  install:
    commands:
      # Install performance monitoring tools
      - npm install -g clinic
      
      # Create performance tracking functions
      - |
        perf_start() {
          echo "PERF_START_$1=$(date +%s)" >> /tmp/perf.log
        }
        
        perf_end() {
          START_VAR="PERF_START_$1"
          if [ -f /tmp/perf.log ] && grep -q "$START_VAR" /tmp/perf.log; then
            START_TIME=$(grep "$START_VAR" /tmp/perf.log | cut -d'=' -f2)
            END_TIME=$(date +%s)
            DURATION=$((END_TIME - START_TIME))
            echo "PERF_$1_DURATION=$DURATION" >> /tmp/perf.log
            echo "Performance: $1 took ${DURATION}s"
          fi
        }

  pre_build:
    commands:
      - perf_start "DEPENDENCY_INSTALL"
      - npm ci
      - perf_end "DEPENDENCY_INSTALL"
      
      - perf_start "LINT"
      - npm run lint
      - perf_end "LINT"

  build:
    commands:
      - perf_start "BUILD"
      
      # Profile build process
      - clinic doctor --on-port 'kill $PID' -- npm run build &
      - BUILD_PID=$!
      - wait $BUILD_PID
      
      - perf_end "BUILD"
      
      # Analyze bundle performance
      - perf_start "BUNDLE_ANALYSIS"
      - npm run analyze-bundle
      - perf_end "BUNDLE_ANALYSIS"

  post_build:
    commands:
      # Generate performance report
      - |
        echo "=== BUILD PERFORMANCE REPORT ==="
        cat /tmp/perf.log
        
        # Send metrics to CloudWatch
        while read line; do
          if [[ $line == PERF_*_DURATION=* ]]; then
            METRIC_NAME=$(echo $line | cut -d'=' -f1 | sed 's/PERF_//g')
            METRIC_VALUE=$(echo $line | cut -d'=' -f2)
            
            aws cloudwatch put-metric-data \
              --namespace "CodeBuild/Performance" \
              --metric-data MetricName=$METRIC_NAME,Value=$METRIC_VALUE,Unit=Seconds \
                           Dimensions=[{Name=ProjectName,Value=$CODEBUILD_PROJECT_NAME}]
          fi
        done < /tmp/perf.log
      
      # Upload performance artifacts
      - |
        if [ -f clinic.doctor.html ]; then
          aws s3 cp clinic.doctor.html s3://build-performance-reports/$CODEBUILD_BUILD_ID/
        fi
```

#### Resource Utilization Monitoring

```yaml
version: 0.2

phases:
  install:
    commands:
      # Start resource monitoring
      - |
        monitor_resources() {
          while true; do
            timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
            cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
            mem_usage=$(free | grep Mem | awk '{printf("%.2f"), $3/$2 * 100.0}')
            disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
            
            echo "$timestamp,CPU:$cpu_usage,MEM:$mem_usage,DISK:$disk_usage" >> /tmp/resource-usage.log
            
            # Send to CloudWatch
            aws cloudwatch put-metric-data \
              --namespace "CodeBuild/Resources" \
              --metric-data \
                MetricName=CPUUtilization,Value=$cpu_usage,Unit=Percent,Dimensions=[{Name=ProjectName,Value=$CODEBUILD_PROJECT_NAME}] \
                MetricName=MemoryUtilization,Value=$mem_usage,Unit=Percent,Dimensions=[{Name=ProjectName,Value=$CODEBUILD_PROJECT_NAME}] \
                MetricName=DiskUtilization,Value=$disk_usage,Unit=Percent,Dimensions=[{Name=ProjectName,Value=$CODEBUILD_PROJECT_NAME}]
            
            sleep 30
          done
        }
        
        monitor_resources &
        MONITOR_PID=$!

  build:
    commands:
      - npm run build
      
    finally:
      # Stop resource monitoring
      - kill $MONITOR_PID 2>/dev/null || true
      - echo "=== RESOURCE USAGE REPORT ==="
      - cat /tmp/resource-usage.log
```

---

## 8. Enterprise and Advanced Features

### Batch Builds and Fleet Management

For large-scale development environments, CodeBuild supports batch builds and build fleet management to handle multiple concurrent builds efficiently.

#### Batch Build Configuration

```json
{
  "projectName": "enterprise-batch-build",
  "buildBatchConfig": {
    "serviceRole": "arn:aws:iam::123456789012:role/service-role/codebuild-batch-service-role",
    "restrictions": {
      "maximumBuildsAllowed": 50,
      "computeTypesAllowed": [
        "BUILD_GENERAL1_SMALL",
        "BUILD_GENERAL1_MEDIUM", 
        "BUILD_GENERAL1_LARGE"
      ]
    },
    "timeoutInMinutes": 120,
    "batchReportMode": "REPORT_AGGREGATED_BATCH"
  }
}
```

#### Advanced Batch Build Strategies

```yaml
version: 0.2

# Multi-environment batch build
batch:
  fast-fail: false
  build-graph:
    - identifier: build-api
      env:
        variables:
          SERVICE: api
          DOCKERFILE: api/Dockerfile
    
    - identifier: build-frontend  
      env:
        variables:
          SERVICE: frontend
          DOCKERFILE: frontend/Dockerfile
    
    - identifier: build-worker
      env:
        variables:
          SERVICE: worker
          DOCKERFILE: worker/Dockerfile
      
    - identifier: integration-tests
      depends-on:
        - build-api
        - build-frontend
        - build-worker
      env:
        variables:
          TEST_TYPE: integration
          
    - identifier: security-scan
      depends-on:
        - build-api
        - build-frontend 
        - build-worker
      env:
        variables:
          SCAN_TYPE: security
          
    - identifier: deploy-staging
      depends-on:
        - integration-tests
        - security-scan
      env:
        variables:
          DEPLOY_ENV: staging

phases:
  install:
    runtime-versions:
      nodejs: 16
      docker: 20
      
  pre_build:
    commands:
      # Configure based on batch identifier
      - echo "Building: $CODEBUILD_BATCH_BUILD_IDENTIFIER"
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

  build:
    commands:
      # Service-specific build logic
      - |
        case $SERVICE in
          api|frontend|worker)
            echo "Building $SERVICE service..."
            cd services/$SERVICE
            docker build -f $DOCKERFILE -t $ECR_REGISTRY/$SERVICE:$CODEBUILD_BUILD_NUMBER .
            docker push $ECR_REGISTRY/$SERVICE:$CODEBUILD_BUILD_NUMBER
            ;;
        esac
      
      # Test-specific logic
      - |
        if [ "$TEST_TYPE" = "integration" ]; then
          echo "Running integration tests..."
          docker-compose -f docker-compose.test.yml up --abort-on-container-exit
        fi
      
      # Security scanning
      - |
        if [ "$SCAN_TYPE" = "security" ]; then
          echo "Running security scans..."
          for service in api frontend worker; do
            docker run --rm aquasec/trivy:latest image $ECR_REGISTRY/$service:$CODEBUILD_BUILD_NUMBER
          done
        fi
      
      # Deployment
      - |
        if [ "$DEPLOY_ENV" = "staging" ]; then
          echo "Deploying to staging..."
          aws ecs update-service --cluster staging --service api --force-new-deployment
          aws ecs update-service --cluster staging --service frontend --force-new-deployment
          aws ecs update-service --cluster staging --service worker --force-new-deployment
        fi
```

### Cross-Account Build Configurations

Enterprise environments often require builds to run across multiple AWS accounts for security and isolation.

#### Cross-Account IAM Setup

**Build Account Service Role**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sts:AssumeRole"
      ],
      "Resource": [
        "arn:aws:iam::PRODUCTION-ACCOUNT:role/CodeBuildCrossAccountRole",
        "arn:aws:iam::STAGING-ACCOUNT:role/CodeBuildCrossAccountRole"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::shared-artifacts-bucket/*"
      ]
    }
  ]
}
```

**Target Account Cross-Account Role**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::BUILD-ACCOUNT:role/service-role/codebuild-service-role"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "unique-external-id"
        }
      }
    }
  ]
}
```

#### Cross-Account Build Implementation

```yaml
version: 0.2

env:
  variables:
    EXTERNAL_ID: unique-external-id
    PRODUCTION_ACCOUNT: "123456789012"
    STAGING_ACCOUNT: "234567890123"
    
  parameter-store:
    CROSS_ACCOUNT_ROLES: /build/cross-account-roles

phases:
  install:
    runtime-versions:
      python: 3.9
    commands:
      - pip install boto3

  pre_build:
    commands:
      # Parse cross-account configuration
      - |
        echo "Configuring cross-account access..."
        ROLES=$(echo $CROSS_ACCOUNT_ROLES | jq -r .)
        PROD_ROLE=$(echo $ROLES | jq -r '.production')
        STAGING_ROLE=$(echo $ROLES | jq -r '.staging')
        
        echo "Production role: $PROD_ROLE"
        echo "Staging role: $STAGING_ROLE"

  build:
    commands:
      # Build application
      - npm run build
      
      # Cross-account deployment function
      - |
        deploy_to_account() {
          local target_role=$1
          local environment=$2
          
          echo "Assuming role: $target_role"
          
          # Create assume role script
          cat > assume_role.py << EOF
        import boto3
        import json
        import os
        
        sts = boto3.client('sts')
        
        response = sts.assume_role(
            RoleArn='$target_role',
            RoleSessionName='CodeBuild-CrossAccount',
            ExternalId='$EXTERNAL_ID'
        )
        
        credentials = response['Credentials']
        
        print(f"export AWS_ACCESS_KEY_ID={credentials['AccessKeyId']}")
        print(f"export AWS_SECRET_ACCESS_KEY={credentials['SecretAccessKey']}")
        print(f"export AWS_SESSION_TOKEN={credentials['SessionToken']}")
        EOF
          
          # Assume role and deploy
          eval $(python assume_role.py)
          
          # Deploy using cross-account credentials
          echo "Deploying to $environment account..."
          aws s3 sync dist/ s3://deployments-$environment-account/
          
          # Trigger deployment in target account
          aws lambda invoke \
            --function-name deploy-application \
            --payload "{\"environment\":\"$environment\",\"buildNumber\":\"$CODEBUILD_BUILD_NUMBER\"}" \
            response.json
          
          # Cleanup credentials
          unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
        }

  post_build:
    commands:
      # Deploy to multiple accounts based on branch
      - |
        BRANCH_NAME=${CODEBUILD_WEBHOOK_HEAD_REF#refs/heads/}
        
        case $BRANCH_NAME in
          main)
            echo "Deploying to production..."
            deploy_to_account "$PROD_ROLE" "production"
            ;;
          develop)
            echo "Deploying to staging..."
            deploy_to_account "$STAGING_ROLE" "staging"
            ;;
          *)
            echo "Branch $BRANCH_NAME does not trigger cross-account deployment"
            ;;
        esac
```

### Build Project Templates and Standardization

Large organizations need standardized build configurations across teams and projects.

#### CloudFormation Template for Standardized Builds

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Standardized CodeBuild project template for enterprise applications'

Parameters:
  ProjectName:
    Type: String
    Description: Name of the build project
    
  ApplicationType:
    Type: String
    Description: Type of application being built
    AllowedValues: [nodejs, python, java, dotnet, docker]
    Default: nodejs
    
  Environment:
    Type: String
    Description: Target environment
    AllowedValues: [development, staging, production]
    Default: development
    
  SourceRepository:
    Type: String
    Description: Source repository URL
    
  NotificationTopic:
    Type: String
    Description: SNS topic for build notifications
    Default: ''

Mappings:
  BuildConfig:
    nodejs:
      Image: aws/codebuild/amazonlinux2-x86_64-standard:4.0
      Runtime: nodejs:18
      ComputeType: BUILD_GENERAL1_MEDIUM
    python:
      Image: aws/codebuild/amazonlinux2-x86_64-standard:4.0
      Runtime: python:3.9
      ComputeType: BUILD_GENERAL1_MEDIUM
    java:
      Image: aws/codebuild/amazonlinux2-x86_64-standard:4.0
      Runtime: java:corretto11
      ComputeType: BUILD_GENERAL1_LARGE
    dotnet:
      Image: aws/codebuild/amazonlinux2-x86_64-standard:4.0
      Runtime: dotnet:6.0
      ComputeType: BUILD_GENERAL1_MEDIUM
    docker:
      Image: aws/codebuild/amazonlinux2-x86_64-standard:4.0
      Runtime: docker:20
      ComputeType: BUILD_GENERAL1_LARGE

Conditions:
  HasNotificationTopic: !Not [!Equals [!Ref NotificationTopic, '']]
  IsProduction: !Equals [!Ref Environment, 'production']

Resources:
  CodeBuildServiceRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: codebuild.amazonaws.com
            Action: sts:AssumeRole
      Policies:
        - PolicyName: CodeBuildServicePolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - logs:CreateLogGroup
                  - logs:CreateLogStream
                  - logs:PutLogEvents
                Resource: !Sub 'arn:aws:logs:${AWS::Region}:${AWS::AccountId}:log-group:/aws/codebuild/${ProjectName}*'
              - Effect: Allow
                Action:
                  - s3:GetObject
                  - s3:GetObjectVersion
                  - s3:PutObject
                Resource:
                  - !Sub '${ArtifactsBucket}/*'
                  - !Sub '${CacheBucket}/*'
              - Effect: Allow
                Action:
                  - codecommit:GitPull
                Resource: !Ref SourceRepository
              - Effect: Allow
                Action:
                  - ssm:GetParameter
                  - ssm:GetParameters
                Resource: !Sub 'arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/${ProjectName}/*'
              - !If
                - HasNotificationTopic
                - Effect: Allow
                  Action:
                    - sns:Publish
                  Resource: !Ref NotificationTopic
                - !Ref 'AWS::NoValue'

  CodeBuildProject:
    Type: AWS::CodeBuild::Project
    Properties:
      Name: !Ref ProjectName
      ServiceRole: !GetAtt CodeBuildServiceRole.Arn
      Artifacts:
        Type: S3
        Location: !Sub '${ArtifactsBucket}/${ProjectName}'
        Name: !Sub '${ProjectName}-artifacts'
      Environment:
        Type: LINUX_CONTAINER
        ComputeType: !FindInMap [BuildConfig, !Ref ApplicationType, ComputeType]
        Image: !FindInMap [BuildConfig, !Ref ApplicationType, Image]
        PrivilegedMode: !Equals [!Ref ApplicationType, 'docker']
        EnvironmentVariables:
          - Name: APPLICATION_TYPE
            Value: !Ref ApplicationType
          - Name: ENVIRONMENT
            Value: !Ref Environment
          - Name: ARTIFACTS_BUCKET
            Value: !Ref ArtifactsBucket
          - Name: CACHE_BUCKET
            Value: !Ref CacheBucket
      Source:
        Type: CODECOMMIT
        Location: !Ref SourceRepository
        BuildSpec: !Sub |
          version: 0.2
          
          phases:
            install:
              runtime-versions:
                ${FindInMap [BuildConfig, !Ref ApplicationType, Runtime]}
              commands:
                - echo "Installing dependencies for ${ApplicationType} application"
                - |
                  case "${ApplicationType}" in
                    nodejs)
                      npm ci
                      ;;
                    python)
                      pip install -r requirements.txt
                      ;;
                    java)
                      mvn dependency:resolve
                      ;;
                    dotnet)
                      dotnet restore
                      ;;
                    docker)
                      echo "Docker build - no dependency installation needed"
                      ;;
                  esac
                  
            pre_build:
              commands:
                - echo "Running pre-build checks"
                - |
                  case "${ApplicationType}" in
                    nodejs)
                      npm run lint || true
                      npm run test:unit
                      ;;
                    python)
                      pylint src/ || true
                      pytest tests/unit/
                      ;;
                    java)
                      mvn checkstyle:check || true
                      mvn test
                      ;;
                    dotnet)
                      dotnet test --logger trx
                      ;;
                    docker)
                      docker --version
                      ;;
                  esac
                  
            build:
              commands:
                - echo "Building ${ApplicationType} application"
                - |
                  case "${ApplicationType}" in
                    nodejs)
                      npm run build
                      ;;
                    python)
                      python setup.py bdist_wheel
                      ;;
                    java)
                      mvn package -DskipTests
                      ;;
                    dotnet)
                      dotnet build --configuration Release
                      dotnet publish --configuration Release --output ./publish
                      ;;
                    docker)
                      docker build -t ${ProjectName}:latest .
                      ;;
                  esac
                  
            post_build:
              commands:
                - echo "Post-build activities"
                - |
                  if [ "${Environment}" = "production" ]; then
                    echo "Production build - running additional validations"
                    case "${ApplicationType}" in
                      nodejs)
                        npm run test:integration
                        ;;
                      python)
                        pytest tests/integration/
                        ;;
                      java)
                        mvn integration-test
                        ;;
                      dotnet)
                        dotnet test --configuration Release
                        ;;
                    esac
                  fi
                  
          artifacts:
            files:
              - '**/*'
            name: ${ProjectName}-${Environment}-artifacts
            
          cache:
            paths:
              - node_modules/**/*
              - ~/.m2/repository/**/*
              - ~/.nuget/packages/**/*
              - ~/.cache/pip/**/*
              
      Cache:
        Type: S3
        Location: !Sub '${CacheBucket}/${ProjectName}'
      TimeoutInMinutes: 60
      Tags:
        - Key: Environment
          Value: !Ref Environment
        - Key: ApplicationType
          Value: !Ref ApplicationType
        - Key: ManagedBy
          Value: CloudFormation

  ArtifactsBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub 'codebuild-artifacts-${AWS::AccountId}-${AWS::Region}-${ProjectName}'
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true
      VersioningConfiguration:
        Status: !If [IsProduction, 'Enabled', 'Suspended']
      LifecycleConfiguration:
        Rules:
          - Status: Enabled
            ExpirationInDays: !If [IsProduction, 90, 30]
            NoncurrentVersionExpirationInDays: 7

  CacheBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub 'codebuild-cache-${AWS::AccountId}-${AWS::Region}-${ProjectName}'
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true
      LifecycleConfiguration:
        Rules:
          - Status: Enabled
            ExpirationInDays: 7

Outputs:
  ProjectName:
    Description: CodeBuild project name
    Value: !Ref CodeBuildProject
    
  ProjectArn:
    Description: CodeBuild project ARN
    Value: !GetAtt CodeBuildProject.Arn
    
  ArtifactsBucket:
    Description: S3 bucket for build artifacts
    Value: !Ref ArtifactsBucket
    
  CacheBucket:
    Description: S3 bucket for build cache
    Value: !Ref CacheBucket
```

#### Automated Testing Integration

```yaml
version: 0.2

# Enterprise testing buildspec template
phases:
  install:
    runtime-versions:
      nodejs: 16
    commands:
      # Install testing tools
      - npm install -g jest newman cypress artillery
      - pip install pytest locust
      
      # Install security scanning tools
      - npm install -g snyk audit-ci
      - pip install bandit safety
      
      # Install quality gates tools
      - curl -o sonar-scanner.zip https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.6.2.2472-linux.zip
      - unzip sonar-scanner.zip
      - mv sonar-scanner-4.6.2.2472-linux /opt/sonar-scanner

  pre_build:
    commands:
      # Security scanning
      - echo "Running security scans..."
      - snyk test --severity-threshold=medium
      - safety check --full-report
      - bandit -r src/ -f json -o security-report.json || true
      
      # Dependency audit
      - audit-ci --moderate
      
      # Code quality analysis
      - /opt/sonar-scanner/bin/sonar-scanner \
          -Dsonar.projectKey=$CODEBUILD_PROJECT_NAME \
          -Dsonar.sources=src/ \
          -Dsonar.host.url=$SONARQUBE_URL \
          -Dsonar.login=$SONARQUBE_TOKEN

  build:
    commands:
      # Application build
      - npm run build
      
      # Unit testing with coverage
      - npm run test:unit -- --coverage --coverageReporters=json-summary --coverageReporters=lcov
      
      # Static analysis
      - npm run lint -- --format junit --output-file lint-results.xml
      
      # Type checking (if TypeScript)
      - npm run type-check || true

  post_build:
    commands:
      # Integration testing
      - |
        if [ "$ENVIRONMENT" = "staging" ] || [ "$ENVIRONMENT" = "production" ]; then
          echo "Running integration tests..."
          npm run test:integration
          
          # API testing with Newman
          newman run tests/postman/api-tests.json --environment tests/postman/env-$ENVIRONMENT.json --reporters junit --reporter-junit-export api-test-results.xml
          
          # End-to-end testing
          cypress run --record --key $CYPRESS_RECORD_KEY --env environment=$ENVIRONMENT
        fi
      
      # Performance testing
      - |
        if [ "$ENVIRONMENT" = "production" ]; then
          echo "Running performance tests..."
          artillery run tests/performance/load-test.yml --output performance-report.json
        fi
      
      # Generate test reports
      - |
        cat > test-summary.json << EOF
        {
          "buildId": "$CODEBUILD_BUILD_ID",
          "testResults": {
            "unitTests": {
              "passed": true,
              "coverage": $(cat coverage/coverage-summary.json | jq '.total.lines.pct')
            },
            "integrationTests": {
              "passed": true
            },
            "e2eTests": {
              "passed": true
            },
            "securityScan": {
              "passed": true,
              "reportLocation": "security-report.json"
            }
          }
        }
        EOF
      
      # Quality gates validation
      - |
        COVERAGE=$(cat coverage/coverage-summary.json | jq '.total.lines.pct')
        if (( $(echo "$COVERAGE < 80" | bc -l) )); then
          echo "Coverage $COVERAGE% is below 80% threshold"
          exit 1
        fi
        
        # Check for critical security issues
        if jq -e '.results | length > 0' security-report.json; then
          echo "Critical security issues found"
          exit 1
        fi

reports:
  unit-tests:
    files:
      - 'jest-junit.xml'
    file-format: JUNITXML
  integration-tests:
    files:
      - 'api-test-results.xml'
    file-format: JUNITXML
  coverage:
    files:
      - 'coverage/lcov.info'
    file-format: COBERTURAXML
  lint:
    files:
      - 'lint-results.xml'
    file-format: JUNITXML

artifacts:
  files:
    - dist/**/*
    - test-summary.json
    - security-report.json
    - performance-report.json
  secondary-artifacts:
    test-reports:
      files:
        - 'coverage/**/*'
        - '*-test-results.xml'
        - 'cypress/videos/**/*'
        - 'cypress/screenshots/**/*'
      name: test-reports-$CODEBUILD_BUILD_NUMBER
```

---

This concludes the comprehensive content for AWS CodeBuild Topic 3. The guide covers all essential aspects from basic setup to enterprise-level configurations, providing practical examples and real-world implementation patterns for the AWS DevOps Engineer Professional certification.