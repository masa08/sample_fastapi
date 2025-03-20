provider "aws" {
  region = "ap-northeast-1"
}

resource "aws_ecr_repository" "fastapi_app" {
  name                 = "fastapi-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

output "repository_url" {
  value = aws_ecr_repository.fastapi_app.repository_url
}
