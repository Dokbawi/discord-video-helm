#!/bin/bash
set -e
echo "🚀 인프라 컴포넌트 배포 시작 (External Secrets 방식)..."

echo "📦 External Secrets CRD 먼저 설치 중..."
kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/charts/external-secrets/crds/bundle.yaml

echo "📦 External Secrets Operator 설치 중..."
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# 기존 설치 확인 후 조건부 실행
if helm list -n external-secrets-system | grep -q external-secrets; then
    echo "External Secrets가 이미 설치되어 있습니다. 업그레이드 중..."
    helm upgrade external-secrets external-secrets/external-secrets -n external-secrets-system --set installCRDs=true
else
    echo "External Secrets 새로 설치 중..."
    helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace --set installCRDs=true
fi

echo "⏳ External Secrets Operator 준비 대기 중..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=external-secrets -n external-secrets-system --timeout=180s

echo "📦 네임스페이스 생성 중..."
kubectl create ns argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create ns discord-video-app --dry-run=client -o yaml | kubectl apply -f -

echo "🔐 Workload Identity 및 Secret Store 설정 중..."
kubectl apply -f workload-identity/

echo "⏳ CRD 등록 확인 중..."
kubectl get crd | grep external-secrets || echo "CRD 등록 대기 중..."
sleep 10

echo "🔑 External Secrets 설정 중..."
kubectl apply -f rabbitmq/rabbitmq-secret.yaml

echo "🎯 ArgoCD 설치 중..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "🔑 ArgoCD External Secret 설정 중..."
kubectl apply -f argocd/argocd-secret.yaml

echo "⏳ Secret 생성 대기 중..."
kubectl wait --for=condition=Ready externalsecret/rabbitmq-secret -n discord-video-app --timeout=120s

echo "🐰 RabbitMQ 배포 중..."
kubectl apply -f rabbitmq/rabbitmq-deployment.yaml

echo "🔧 ArgoCD 서비스를 LoadBalancer로 변경 중..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

echo "✅ 인프라 배포 완료!"
echo ""
echo "📋 접속 정보:"
echo "🎯 ArgoCD:"
echo "   외부 IP 확인: kubectl get svc argocd-server -n argocd"
echo "   사용자명: admin"
echo "   비밀번호: ArgoCD 자동 생성 (아래 명령어로 확인)"
echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo "🐰 RabbitMQ:"
echo "   포트 포워딩: kubectl port-forward svc/rabbitmq-service -n discord-video-app 15672:15672"
echo "   URL: http://localhost:15672"
echo "   사용자명: admin"
echo "   비밀번호: GCP Secret Manager에서 확인"