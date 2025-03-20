#!/bin/bash

# Variables
AWS_REGION="ap-northeast-1"
ECR_REPOSITORY="fastapi-app"
IMAGE_TAG="latest"

# Authenticate Docker to AWS ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $(aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $AWS_REGION --query "repositories[0].repositoryUri" --output text)

# Build the Docker image
docker build -t $ECR_REPOSITORY .

# Tag the Docker image
REPOSITORY_URI=$(aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $AWS_REGION --query "repositories[0].repositoryUri" --output text)
docker tag $ECR_REPOSITORY:latest $REPOSITORY_URI:$IMAGE_TAG

# Push the Docker image to ECR
docker push $REPOSITORY_URI:$IMAGE_TAG