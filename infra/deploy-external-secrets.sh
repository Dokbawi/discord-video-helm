set -e
echo "🚀 인프라 컴포넌트 배포 시작 (External Secrets 방식)..."

echo "📦 External Secrets Operator 설치 중..."
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace

kubectl create ns argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create ns discord-video-app --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f infra/workload-identity/

kubectl apply -f infra/rabbitmq/rabbitmq-secret.yaml

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f infra/argocd/argocd-secret.yaml

echo "⏳ Secret 생성 대기 중..."
kubectl wait --for=condition=Ready externalsecret/rabbitmq-secret -n discord-video-app --timeout=60s
kubectl apply -f infra/rabbitmq/rabbitmq-deployment.yaml

echo "✅ 인프라 배포 완료!"