#!/bin/bash

set -e

KIND_CLUSTER_NAME="discord-video-local"
HELM_RELEASE_NAME="discord-video-app"
NAMESPACE="discord-video-app"
CHART_PATH="." 
VALUES_FILE="values-development.yaml"

# 서비스 목록과 레포 경로 매핑
declare -A SERVICES=(
    ["discord-bot"]="../discord-bot"
    ["winter-cat-video"]="../winter-cat-video" 
    ["codex-media"]="../codex-media"
)

BASE_IMAGE_TAG="local"

# 현재 타임스탬프를 기반으로 고유한 이미지 태그 생성
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
IMAGE_TAG="${BASE_IMAGE_TAG}-${TIMESTAMP}"

# 강제 재빌드 옵션
FORCE_REBUILD=false
if [[ "$1" == "--force-rebuild" ]]; then
    FORCE_REBUILD=true
    echo "🔥 Force rebuild mode enabled"
fi

echo "🏗️  [1/6] Building Docker images with tag: ${IMAGE_TAG}..."

# 빌드가 필요한 서비스 확인
SERVICES_TO_BUILD=()

for service in "${!SERVICES[@]}"; do
    service_path="${SERVICES[$service]}"
    
    # 서비스 레포 디렉토리가 존재하는지 확인
    if [[ ! -d "$service_path" ]]; then
        echo "⚠️  Warning: Service repository not found: $service_path"
        echo "  Please make sure all service repositories are cloned as sibling directories"
        continue
    fi
    
    # 강제 재빌드가 아닌 경우, Git 변경사항 확인
    if [[ "$FORCE_REBUILD" == "false" ]]; then
        # 기존 로컬 이미지가 있는지 확인
        if docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "^${service}:${BASE_IMAGE_TAG}"; then
            # Git에서 최근 커밋 확인 (마지막 빌드 이후 변경사항)
            cd "$service_path"
            # 최근 1시간 내 커밋이 있는지 확인
            recent_commits=$(git log --since="1 hour ago" --oneline | wc -l)
            cd - > /dev/null
            
            if [[ $recent_commits -eq 0 ]]; then
                echo "  ⏭️  Skipping ${service} (no recent commits)"
                continue
            fi
        fi
    fi
    
    SERVICES_TO_BUILD+=("$service")
done

# 빌드할 서비스가 없는 경우
if [[ ${#SERVICES_TO_BUILD[@]} -eq 0 ]]; then
    echo "  ✅ No services need rebuilding"
    IMAGE_TAG="${BASE_IMAGE_TAG}"
else
    # 각 서비스별 Docker 이미지 빌드
    for service in "${SERVICES_TO_BUILD[@]}"; do
        service_path="${SERVICES[$service]}"
        echo "  📦 Building ${service}:${IMAGE_TAG}..."
        
        # 서비스 레포로 이동해서 빌드
        cd "$service_path"
        
        # Git 최신 상태로 업데이트 (옵션)
        echo "    🔄 Pulling latest changes for ${service}..."
        git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || echo "    ⚠️  Could not pull latest changes (working with current state)"
        
        # Docker 이미지 빌드
        if [[ -f "Dockerfile" ]]; then
            docker build -t ${service}:${IMAGE_TAG} .
        else
            echo "    ⚠️  Warning: No Dockerfile found in ${service_path}"
            cd - > /dev/null
            continue
        fi
        
        # latest 태그도 생성
        docker tag ${service}:${IMAGE_TAG} ${service}:${BASE_IMAGE_TAG}
        
        echo "  ✅ ${service}:${IMAGE_TAG} built successfully"
        
        # 원래 디렉토리로 복귀
        cd - > /dev/null
    done
fi

echo "📤 [2/6] Loading images into Kind cluster..."

# Kind 클러스터에 이미지 로드
for service in "${!SERVICES[@]}"; do
    echo "  🚀 Loading ${service}:${IMAGE_TAG} into kind cluster..."
    kind load docker-image ${service}:${IMAGE_TAG} --name ${KIND_CLUSTER_NAME}
    echo "  ✅ ${service}:${IMAGE_TAG} loaded into kind cluster"
done

echo "🌐 [3/6] Setting kube context to kind-${KIND_CLUSTER_NAME}..."
kubectl config use-context kind-${KIND_CLUSTER_NAME}

echo "📁 [4/6] Creating namespace (if not exists)..."
kubectl get namespace ${NAMESPACE} >/dev/null 2>&1 || kubectl create namespace ${NAMESPACE}

echo "🚀 [5/6] Deploying via Helm with new image tags..."

# Helm에 새로운 이미지 태그 전달
helm upgrade --install ${HELM_RELEASE_NAME} ${CHART_PATH} \
  --namespace ${NAMESPACE} \
  --values ${VALUES_FILE} \
  --set images.discordBot.tag=${IMAGE_TAG} \
  --set images.winterCatVideo.tag=${IMAGE_TAG} \
  --set images.codexMedia.tag=${IMAGE_TAG} \
  --wait \
  --timeout=300s

echo "✅ [6/6] Deployment complete! Image tag used: ${IMAGE_TAG}"
echo "📊 Current Pods:"
kubectl get pods -n ${NAMESPACE}

echo ""
echo "🔍 Pod Status Details:"
kubectl get pods -n ${NAMESPACE} -o wide

echo ""
echo "📝 Recent Events:"
kubectl get events -n ${NAMESPACE} --sort-by='.lastTimestamp' | tail -10

# 배포 상태 확인
echo ""
echo "⏳ Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=${HELM_RELEASE_NAME} -n ${NAMESPACE} --timeout=300s

echo ""
echo "🎉 All services are ready!"
echo "📋 Service URLs (if applicable):"
kubectl get svc -n ${NAMESPACE}

echo ""
echo "💡 Useful commands:"
echo "  View logs: kubectl logs -f deployment/<service-name> -n ${NAMESPACE}"
echo "  Port forward: kubectl port-forward svc/<service-name> <local-port>:<service-port> -n ${NAMESPACE}"
echo "  Shell access: kubectl exec -it deployment/<service-name> -n ${NAMESPACE} -- /bin/sh"