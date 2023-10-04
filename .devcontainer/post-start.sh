#!/bin/bash

USERNAME=vscode

echo "post-start start" >> /home/$USERNAME/status

echo "Creating kind cluster..."
kind create cluster

echo "Created kind cluster"

echo "Deploy ArgoCD"
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Wait for ArgoCD to be ready..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

kubectl -n argocd rollout status deploy/argocd-server --timeout=300s

kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
