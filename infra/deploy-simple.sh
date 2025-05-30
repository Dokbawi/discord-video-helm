#!/bin/bash
set -e

echo "🚀 인프라 컴포넌트 배포 시작..."

# htpasswd 없이도 가능 - 평문 패스워드 사용

echo "📦 네임스페이스 생성 중..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace discord-video-app --dry-run=client -o yaml | kubectl apply -f -

echo "🔐 GCP Secret Manager에서 패스워드 가져오는 중..."
ARGOCD_ADMIN_PASSWORD=$(gcloud secrets versions access latest --secret="argocd-admin-password")
RABBITMQ_PASSWORD=$(gcloud secrets versions access latest --secret="rabbitmq-password")

echo "🔑 RabbitMQ Secret 생성 중..."
kubectl delete secret rabbitmq-credentials -n discord-video-app --ignore-not-found=true
kubectl create secret generic rabbitmq-credentials \
  -n discord-video-app \
  --from-literal=username=admin \
  --from-literal=rabbitmq-password="$RABBITMQ_PASSWORD"

echo "🎯 ArgoCD 설치 중..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "⏳ ArgoCD 서버 시작 대기 중..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo "🐰 RabbitMQ 배포 중..."
# RabbitMQ 관련 리소스들 적용

kubectl apply -f rabbitmq/rabbitmq-deployment.yaml

echo "⏳ 서비스 준비 대기 중..."
sleep 30

echo "✅ 인프라 배포 완료!"
echo ""
echo "📋 접속 정보:"

# ArgoCD 외부 IP 확인
echo "🎯 ArgoCD 정보:"
ARGOCD_EXTERNAL_IP=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "대기 중...")
if [ "$ARGOCD_EXTERNAL_IP" != "대기 중..." ] && [ -n "$ARGOCD_EXTERNAL_IP" ]; then
    echo "   URL: https://$ARGOCD_EXTERNAL_IP"
    echo "   사용자명: admin"
    echo "   비밀번호: $ARGOCD_ADMIN_PASSWORD"
else
    echo "   외부 IP 할당 대기 중... 다음 명령어로 확인하세요:"
    echo "   kubectl get svc argocd-server -n argocd"
    echo "   사용자명: admin"
    echo "   비밀번호: $ARGOCD_ADMIN_PASSWORD"
fi

echo ""
echo "🐰 RabbitMQ 정보:"
echo "   포트 포워딩: kubectl port-forward svc/rabbitmq-service -n discord-video-app 15672:15672"
echo "   URL: http://localhost:15672"
echo "   사용자명: admin"
echo "   비밀번호: $RABBITMQ_PASSWORD"

echo ""
echo "🔍 상태 확인 명령어:"
echo "   kubectl get pods -n argocd"
echo "   kubectl get pods -n discord-video-app"