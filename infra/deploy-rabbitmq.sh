#!/bin/bash

# 설정
NAMESPACE="discord-video-app"
SECRET_NAME="rabbitmq-credentials"
SECRET_KEY="rabbitmq-password"
USERNAME="admin"

# GCP Secret Manager에서 최신 버전의 rabbitmq-password 가져오기
echo "🔑 GCP Secret Manager에서 비밀번호 가져오는 중..."
RABBITMQ_PASSWORD=$(gcloud secrets versions access latest --secret="$SECRET_KEY")

if [[ -z "$RABBITMQ_PASSWORD" ]]; then
  echo "❌ 비밀번호를 가져오지 못했습니다. 종료합니다."
  exit 1
fi

# Kubernetes Secret 생성 또는 업데이트
echo "🚀 Kubernetes Secret [$SECRET_NAME] 생성 또는 갱신 중..."

kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE" --ignore-not-found

kubectl create secret generic "$SECRET_NAME" \
  -n "$NAMESPACE" \
  --from-literal=username="$USERNAME" \
  --from-literal=rabbitmq-password="$RABBITMQ_PASSWORD"

echo "✅ 완료: Secret [$SECRET_NAME] 생성됨"


kubectl apply -f /rabbitmq 

echo "✅ 완료: rabbitmq 배포됨"