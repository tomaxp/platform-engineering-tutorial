# Platform Engineering

** WORK IN PROGRESS **

Click "Use this template" to create a new repo in your account.

## i) Preparation: Install tools on your local machine

These tools should be installed on the machine you will use to interact with the cluster:

```
###########
# Install kubectl
# This is used to interact with your cluster
###########
curl -LO https://dl.k8s.io/release/v1.27.4/bin/linux/amd64/kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
# remove copy in ~
rm kubectl

################
# Install helm
# This is used once to install Argo
# TODO: Investigate use of ArgoCD Autopilot
# So that everything (inc. Argo install can live in Git)
# https://argocd-autopilot.readthedocs.io/en/stable/
################
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
sudo chmod +x /usr/local/bin/helm
rm get_helm.sh

#################
# Install sealed secrets kubeseal
# This is necessary to encrypt the Kubernetes Secret values
#################
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.1/kubeseal-0.24.1-linux-amd64.tar.gz
tar -xf kubeseal-0.24.1-linux-amd64.tar.gz
sudo chmod +x kubeseal
sudo mv kubeseal /usr/local/bin
rm kubeseal-0.24.1-linux-amd64.tar.gz
# Restore overwritten files
git restore LICENSE
git restore README.md
```

## ii) Preparation: Update repoURL
The ArgoCD platform app configuration currently points to the parent repository. Change this now.

In the following files, change the `repoUrl` field:

- [gitops/app-of-apps.yml](gitops/app-of-apps.yml#L12)
- [gitops/applications/dynatrace.yml](gitops/applications/dynatrace.yml#L12)
- [gitops/applications/opentelemetry.yml](gitops/applications/opentelemetry.yml#L12)
- [gitops/applications/webhook.site.yml](gitops/applications/webhook.site.yml#L12)

Replace `https://github.com/dynatrace-perfclinics/platform-engineering-tutorial.git` with the URL of your repository URL.

Commit those changes:

```
git add gitops/app-of-apps.yml
git commit -m "update repoURL"
git push
```

Any changes you make to files will now be picked up automatically by ArgoCD and synced to the cluster.


> You should have access to an empty kubernetes cluster.
> Make sure you can `kubectl get namespaces` successfully before proceeding.

## 1) Install and configure ArgoCD on the 

```
# Install Argo
# TODO: Improve
# Investigate use of ArgoCD Autopilot to bootstrap cluster
# https://argocd-autopilot.readthedocs.io/en/stable/
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Configuring ArgoCD for access without TLS
# and preconfigure Argo traces to go to the collector
# OTEL collector will be deployed later
kubectl -n argocd apply -f .devcontainer/argocd-cm.yml
```

`kubectl get ns` should show a new namespace called `argocd`

## 1) Port forward to access argocd

```
kubectl -n argocd port-forward svc/argocd-server 8080:80
```

This command will appear to hang. That is OK. Leave it running.

Open a new terminal for any new commands you need to run.

## 2) Login to Argo

Switch back to the terminal window and print out the argocd password:

```
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo $ARGOCD_PASSWORD
```

Username: `admin`
Password: `see above`

Go to `http://localhost:8080` and log in to Argo.

The UI should show "No Applications".

## 3) Apply Platform App

The "platform" application uses the ArgoCD ["app of apps" concept](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/) to install many applications inside one "parent" app.

This tutorial uses is to bootstrap the cluster:

```
kubectl -n argocd apply -f gitops/app-of-apps.yml
```

## 4) Create Dynatrace Secret to Activate the OneAgent

The OneAgent operator is deployed on the cluster in the step above. However it doesn't have your DT tenant details.

> Note: You need to modify the commands below. DO NOT just copy and paste.

1. Note your DT tenant URL. Like `https://xyz3344.live.dynatrace.com` (no trailing slash)
1. Go to your Dynatrace environment.
1. Go to install OneAgent Kubernetes page.
1. Click "Create Token" next to "Dynatrace Operator token". Copy the value and set it in the command below.
1. Click "Create Token" next to "Data ingest token". Copy the value and set it in the command below

> Note: `history -d $(history 1)` is used for security. It removes the value from history file.

```
DT_TENANT=YOURURLHERE; history -d $(history 1)
```

Now set the operator token:
```
DT_OP_TOKEN=YOURTOKENVALUEHERE; history -d $(history 1)
```

Now set the data ingest token:
```
DT_INGEST_TOKEN=YOURTOKENVALUEHERE; history -d $(history 1)
```

You can copy and paste the command below as-is.

The secret is encrypted using a key on the cluster thus can only be decrypted by the operator on the cluster. Therefore the encrypted `SealedSecret` resource YAML is **safe to commit to Git**.

When the `SealedSecret` is deployed on the cluster, the `SealedSecret` operator will decrypt it and create a regular `kind: Secret` on the cluster.

Encrypt the values and commit the secret to Git:
```
sed -i "s#https://abc12345.live.dynatrace.com#$DT_TENANT#g" gitops/manifests/dynatrace/dynatrace.yml
kubectl -n dynatrace create secret generic hot-day-platform-engineering --dry-run=client --from-literal=apiToken=$DT_OP_TOKEN --from-literal=dataIngestToken=$DT_INGEST_TOKEN -o yaml | kubeseal -o yaml > gitops/manifests/dynatrace/dynakubesecret.yml
git add gitops/manifests/dynatrace/*
git commit -m "add oneagent + encrypted secret"
git push
```

## 5) Create Dynatrace OpenTelemetry Ingest Token

An OpenTelemetry collector is deployed but does not have the DT endpoint details. Using the same method as above, create those details now.

> Note: You need to modify the commands below. DO NOT just copy and paste.

1. Note your DT tenant URL. Like `https://xyz3344.live.dynatrace.com` (no trailing slash)
1. Go to your Dynatrace environment.
1. Go to "Access Tokens"
1. Generate an access token with `openTelemetry.ingest` permissions

> Note: `history -d $(history 1)` is used for security. It removes the value from history file.

Set the Dynatrace URL:

```
DT_TENANT=YOURURLHERE; history -d $(history 1)
```

Now set the OpenTelemetry access token value:

```
DT_INGEST_TOKEN=YOURAPITOKENVALUEHERE; history -d $(history 1)
```

Encrypt the values and commit the secret to Git:
```
kubectl -n opentelemetry create secret generic dt-details --dry-run=client --from-literal=DT_URL=$DT_TENANT --from-literal=DT_OTEL_TRACE_INGEST_TOKEN=$DT_INGEST_TOKEN -o yaml | kubeseal -o yaml > gitops/manifests/opentelemetry/dynatrace-opentelemetry-ingest-secret.yml
git add gitops/manifests/opentelemetry/*
git commit -m "add dt url and opentelemetry token to encrypted secret"
git push
```

## Recap

By now, you should see 5 applications in ArgoCD:
- platform (deployed in wave 1)
- sealed-secrets (deployed in wave 1)
- opentelemetry-collector (deployed in wave 1)
- opentelemetry (deployed in wave 2)
- dynatrace (deployed in wave 2)
- webhook.site (deployed in wave 2)

The OneAgent should connect to your DT environment and be visible within a few moments.


-----------------------------------------

### Additional Info to be sorted

### ArgoCD Traces

Argo is configured (when you `kubectl apply` [.devcontainer/argocd-cm.ym](.devcontainer/argocd-cm.yml) to send OpenTelemetry traces to the OTEL collector.

[The collector is configured](gitops/applications/opentelemetry-collector-contrib.yml#L33-#L45) to send traces to DT.

#### Webhook.site

Webhook.site is an on-cluster UI which allows us to `curl POST` payloads and it'll show in the UI.
It is available in the `webhook` namespace on port `8084`.

The first time you load the URI, it generates a UUID. You use that to interact with the endpoint.

However, we can precreate the endpoint (we could do this on cluster creation) so we know (and can GitOps preconfigure) the endpoints.

[See here for how to do this](https://github.com/webhooksite/webhook.site/issues/151).

#### Triggering Monaco

We could use [Argo Hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/#usage) to trigger a `Job` or workflow when the initial deployment is done.

For example, when the `dynatrace` application is synced and healthy, we use the `PostSync` hook to trigger a `curlimage/curl` Job which triggers a DT workflow to trigger Monaco.
