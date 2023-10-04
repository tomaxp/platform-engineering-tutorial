#!/bin/bash

echo "post-start start" >> ~/status

echo "Creating kind cluster..."
kind create cluster

echo "Created kind cluster"
echo "Applying nginx demo app"
kubectl apply -f .devcontainer/nginxdemo.yml
echo "Applying ArgoCD nodeport"
kubectl apply -f .devcontainer/argocd-nodeport.yaml

# this runs in background each time the container starts

echo "post-start complete" >> ~/status