#!/bin/bash

# deploy.sh - GKE 클러스터 내부 helm 사용
set -e

# 기본값 설정
NAMESPACE="discord-video-app"
RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD:-"defaultpassword"}
DISCORD_BOT_TAG=${DISCORD_BOT_TAG:-"latest"}
WINTER_CAT_TAG=${WINTER_CAT_TAG:-"latest"}
CODEX_MEDIA_TAG=${CODEX_MEDIA_TAG:-"latest"}
RELEASE_NAME=${RELEASE_NAME:-"discord-video"}

echo "=== Discord Video App Helm 배포 시작 ==="
echo "Release Name: $RELEASE_NAME"
echo "Namespace: $NAMESPACE"
echo "Discord Bot Tag: $DISCORD_BOT_TAG"
echo "Winter Cat Tag: $WINTER_CAT_TAG"
echo "Codex Media Tag: $CODEX_MEDIA_TAG"

# Helm 버전 확인
echo "=== Helm 버전 확인 ==="
helm version --short

# Helm 리포지토리 업데이트 (필요한 경우)
echo "=== Helm 리포지토리 업데이트 ==="
helm repo update || echo "리포지토리 업데이트 스킵"

# Helm으로 배포/업그레이드
echo "=== Helm 배포/업그레이드 시작 ==="
helm upgrade --install $RELEASE_NAME . \
  --namespace=$NAMESPACE \
  --create-namespace \
  --values=values.yaml \
  --set rabbitmq.auth.password="$RABBITMQ_PASSWORD" \
  --set images.discordBot.tag="$DISCORD_BOT_TAG" \
  --set images.winterCatVideo.tag="$WINTER_CAT_TAG" \
  --set images.codexMedia.tag="$CODEX_MEDIA_TAG" \
  --wait --timeout=10m

# 배포 상태 확인
echo "=== 배포 상태 확인 ==="
helm status $RELEASE_NAME -n $NAMESPACE

echo "=== Pod 상태 확인 ==="
kubectl get pods -n $NAMESPACE

echo "=== Service 상태 확인 ==="
kubectl get services -n $NAMESPACE

echo "=== 배포 완료! ==="

# 선택사항: 배포 정보 출력
echo "=== 배포 정보 ==="
echo "Release: $RELEASE_NAME"
echo "Namespace: $NAMESPACE"
echo "Chart Version: $(helm list -n $NAMESPACE -o json | jq -r ".[] | select(.name==\"$RELEASE_NAME\") | .chart")"
echo "App Version: $(helm list -n $NAMESPACE -o json | jq -r ".[] | select(.name==\"$RELEASE_NAME\") | .app_version")"