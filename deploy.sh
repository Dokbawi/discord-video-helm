#!/bin/bash
# deploy.sh

set -e

ENVIRONMENT=${1:-development}
NAMESPACE="discord-video-app"
RELEASE_NAME="discord-video-app"
CHART_DIR=$(dirname "$0")

VALUES_FILE="values-${ENVIRONMENT}.yaml"

echo "🚀 Deploying [$RELEASE_NAME] to [$ENVIRONMENT] environment in namespace [$NAMESPACE]..."

# values 파일 존재 확인
if [ ! -f "$CHART_DIR/$VALUES_FILE" ]; then
  echo "❌ Values file '$VALUES_FILE' not found in $CHART_DIR"
  exit 1
fi

# Helm 릴리스 존재 여부 확인
if helm status "$RELEASE_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
  echo "📝 Upgrading existing Helm release [$RELEASE_NAME]..."
  COMMAND="upgrade"
  EXTRA="--reuse-values"
else
  echo "🆕 Installing new Helm release [$RELEASE_NAME]..."
  COMMAND="install"
  EXTRA="--create-namespace"
fi

# Helm 배포 실행
helm $COMMAND $RELEASE_NAME $CHART_DIR \
  --namespace $NAMESPACE \
  --values "$CHART_DIR/$VALUES_FILE" \
  $EXTRA \
  --wait \
  --timeout 10m

echo "✅ Helm $COMMAND completed!"

# 배포 상태 확인
echo "📊 Checking pod status in namespace [$NAMESPACE]..."
kubectl get pods -n $NAMESPACE
