#!/bin/bash

# Helm 배포 실행
git add .
git commit -m "update version"
git push origin master


# 배포 상태 확인
echo "DONE"

