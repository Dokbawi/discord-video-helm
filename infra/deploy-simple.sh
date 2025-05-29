set -e
echo "🚀 인프라 컴포넌트 배포 시작 (간단한 방식)..."

echo "📦 네임스페이스 생성 중..."
kubectl create ns argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create ns discord-video-app --dry-run=client -o yaml | kubectl apply -f -

echo "🔐 GCP Secret Manager에서 패스워드 가져오는 중..."
ARGOCD_ADMIN_PASSWORD=$(gcloud secrets versions access latest --secret="argocd-admin-password")
RABBITMQ_PASSWORD=$(gcloud secrets versions access latest --secret="rabbitmq-password")

echo "🔑 Kubernetes Secret 생성 중..."
kubectl delete secret argocd-initial-admin-secret -n argocd --ignore-not-found
kubectl create secret generic argocd-initial-admin-secret \
  -n argocd \
  --from-literal=password="$(echo -n "$ARGOCD_ADMIN_PASSWORD" | htpasswd -niB "" | cut -d: -f2)"

kubectl delete secret rabbitmq-credentials -n discord-video-app --ignore-not-found
kubectl create secret generic rabbitmq-credentials \
  -n discord-video-app \
  --from-literal=username=admin \
  --from-literal=rabbitmq-password="$RABBITMQ_PASSWORD"

echo "🎯 ArgoCD 설치 중..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "🐰 RabbitMQ 배포 중..."
kubectl apply -f rabbitmq/rabbitmq-deployment.yaml

echo "✅ 인프라 배포 완료!"
echo ""
echo "📋 다음 단계:"
echo "1. ArgoCD UI 접속: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "2. ArgoCD 로그인: admin / $ARGOCD_ADMIN_PASSWORD"
echo "3. RabbitMQ 관리 UI: kubectl port-forward svc/rabbitmq-service -n discord-video-app 15672:15672"
echo "4. RabbitMQ 로그인: admin / $RABBITMQ_PASSWORD"