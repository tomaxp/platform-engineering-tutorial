#!/bin/bash

USERNAME=vscode

echo "post-start start" >> /home/$USERNAME/status

#echo "Creating kind cluster..."
#kind create cluster

echo "Created kind cluster"

echo "Deploy ArgoCD"
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

#echo "Wait for ArgoCD to be ready..."
#kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

echo "Configuring ArgoCD for no TLS"
kubectl -n argocd apply -f .devcontainer/argocd-no-tls.yaml

echo "Restarting ArgoCD server to pick up TLS changes"
kubectl -n argocd scale deploy/argocd-server --replicas=0
kubectl -n argocd scale deploy/argocd-server --replicas=1

kubectl -n argocd rollout status deploy/argocd-server --timeout=300s

kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
