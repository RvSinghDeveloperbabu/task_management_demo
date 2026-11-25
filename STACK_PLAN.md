# Stack Plan: what is done, what is left, and how to practice

This file is a learning plan for the Task Queue Demo app.
It lists the tools from [README.md](README.md), shows which ones you have already used, and gives a step by step plan for the rest.

Last checked: 2026-11-25 (by looking at the files in this folder).

---

## 1. Quick status

| # | Tool / Stack | Status | Proof in this folder |
|---|--------------|--------|----------------------|
| 1 | Docker (Dockerfile) | Done | `backend/Dockerfile`, `frontend/Dockerfile`, `.dockerignore` files |
| 2 | Docker Compose (local run) | Done | `docker-compose.yml` |
| 3 | Kubernetes (plain YAML) | Done | `k8s/` has Namespace, ConfigMap, Secret, Deployment, Service, Ingress, Job |
| 4 | Terraform: VPC | Done | `terraform/vpc.tf`, `subnets.tf` |
| 5 | Terraform: EKS | Done | `terraform/eks.tf` |
| 6 | Terraform: RDS Postgres | Done | `terraform/aws_rds.tf`, `security-group.tf` |
| 7 | AWS Load Balancer Controller (IAM) | Done | `terraform/lb-controller-iam.tf`, `k8s/30_ingress.yaml` |
| 8 | Health probes (/health, /ready) | Partly done | Endpoints exist in the Rails app. Check that the Deployments use them |
| 9 | AWS ECR (image registry) | Partly done | README shows the push commands. No Terraform for ECR repos yet |
| 10 | Redis as ElastiCache | Not done | Redis runs inside k8s (`k8s/11_redis_deployment.yml`). No ElastiCache in Terraform |
| 11 | Helm | Not done | No `helm/` folder |
| 12 | CI/CD (GitHub Actions or GitLab CI) | Not done | No `.github/` or `.gitlab-ci.yml` |
| 13 | HPA (autoscaling for backend) | Not done | No HorizontalPodAutoscaler file |
| 14 | KEDA (queue based scaling for Sidekiq) | Not done | No KEDA files |

**Done:** 7 of 14. **Partly done:** 2. **Remaining:** 5 (plus the bonus tools in section 4).

---

## 2. Cost warning (please read first)

Most tools below are free. Some AWS services are **not free**:

- **EKS control plane**: about 0.10 USD per hour.
- **NAT Gateway**: costs per hour plus data. It is already in your Terraform.
- **RDS** and **ElastiCache**: cost per hour (small free tier may apply for new accounts).
- **Load Balancer** (from Ingress): costs per hour.

How to keep the cost low:

1. Do the free local steps first (Helm, HPA, KEDA, CI/CD) on a local cluster like **kind** or **minikube**. They are free.
2. Use AWS only when needed. When you finish for the day, run `terraform destroy`.
3. Set a **Billing Budget alert** in AWS (for example 10 USD).
4. Do not commit `terraform.tfstate`, `.tfvars` with secrets, or `.env` files to Git.

---

## 3. Plan for the remaining stack

Suggested order (each step builds on the one before):

```
Step 1  Fix probes        (small, 30 min)
Step 2  Helm              (free, local)
Step 3  HPA               (free, local)
Step 4  KEDA              (free, local)
Step 5  ECR with Terraform (cheap)
Step 6  CI/CD             (free tier)
Step 7  ElastiCache       (costs money, do last, then destroy)
```

### Step 1: Probes (finish what you started)

**What:** Tell Kubernetes how to check if each pod is alive and ready.
**Where:** `k8s/12_rails_api_deployment.yml`, `k8s/20_reactjs_frontend.yaml`, `k8s/13_rails_sidekiq_deployment.yml`.
**How:**

1. Backend: add `livenessProbe` on `GET /health` port 3000, and `readinessProbe` on `GET /ready` port 3000.
2. Frontend: add a probe on `GET /healthz` port 8080.
3. Sidekiq: no HTTP port. Set `terminationGracePeriodSeconds: 30` so running jobs can finish.
4. Test: scale Redis to 0 (`kubectl scale deployment redis --replicas=0 -n <namespace>`). Watch `/ready` return 503 and the backend pod leave the Service. Scale Redis back to 1.

**You learn:** liveness vs readiness, graceful shutdown.

---

### Step 2: Helm

**What:** Helm is a package manager for Kubernetes. One chart replaces many YAML files, and `values.yaml` holds the settings (image tag, replicas, env).
**Where:** New folder `helm/task-app/`.
**How:**

1. Install Helm (ask first, it changes your machine): `brew install helm`.
2. Create the chart: `helm create helm/task-app`. Delete the sample templates you do not need.
3. Copy your files from `k8s/` into `helm/task-app/templates/` one by one:
   - Deployments for backend, frontend, sidekiq
   - Services, ConfigMap, Ingress
   - Migration Job as a Helm hook (`helm.sh/hook: pre-install,pre-upgrade`)
4. Replace fixed values with `{{ .Values.xxx }}`. Example: image tag, replica count, `TASK_PROCESSING_SECONDS`.
5. Make separate value files: `values-local.yaml` and `values-aws.yaml`.
6. Commands to practice:
   ```bash
   helm lint helm/task-app
   helm template task-app helm/task-app -f helm/task-app/values-local.yaml   # only prints YAML
   helm install task-app helm/task-app -n task-app --create-namespace
   helm upgrade task-app helm/task-app --set sidekiq.replicas=3
   helm rollback task-app 1
   helm uninstall task-app -n task-app
   ```

**Do not put real passwords in `values.yaml`.** Keep the Secret outside Git or use `--set` / a secret manager.
**You learn:** templates, values, hooks, upgrade and rollback.

---

### Step 3: HPA (Horizontal Pod Autoscaler) for the backend

**What:** Kubernetes adds or removes backend pods when CPU goes up or down.
**Where:** `k8s/40_backend_hpa.yaml` (or a template in the Helm chart).
**How:**

1. Install **metrics-server** (free, needed by HPA). On kind/minikube: `minikube addons enable metrics-server`. On EKS: install the metrics-server manifest or Helm chart.
2. Add CPU `requests` and `limits` to the backend Deployment. HPA does not work without `requests`.
3. Create the HPA: min 2, max 6 pods, target 60% CPU.
4. Make load: run a small loop with `hey` or `ab` (or a `kubectl run` busybox loop) against `/api/tasks`.
5. Watch: `kubectl get hpa -w` and `kubectl get pods -w`.

**You learn:** requests/limits, metrics, scale up and scale down.

---

### Step 4: KEDA for Sidekiq (queue based scaling)

**What:** KEDA scales pods by the **number of jobs waiting in Redis**, not by CPU. This is the right way to scale workers.
**Where:** `k8s/41_sidekiq_keda.yaml` (or Helm template).
**How:**

1. Install KEDA with Helm (free):
   ```bash
   helm repo add kedacore https://kedacore.github.io/charts
   helm install keda kedacore/keda -n keda --create-namespace
   ```
2. Create a `ScaledObject` for the `sidekiq` Deployment. Use the **redis** scaler and look at the Sidekiq queue list (`queue:default`).
3. Set min 1 (or 0), max 10, and a list length target like 5.
4. Raise `TASK_PROCESSING_SECONDS` to 20 so jobs stay in the queue longer.
5. Add 50 tasks fast in the UI (or with a `curl` loop). Watch Sidekiq pods grow, then shrink to the minimum.
6. Open the UI and see different **worker pod names** on finished tasks.

**You learn:** event driven scaling, scale to zero, why CPU is a bad signal for queues.

---

### Step 5: ECR with Terraform

**What:** Private image registry on AWS, created by code instead of by hand.
**Where:** New file `terraform/ecr.tf`.
**How:**

1. Create two `aws_ecr_repository` resources: `task-app-backend` and `task-app-frontend`.
2. Turn on `image_scanning_configuration { scan_on_push = true }`.
3. Add an `aws_ecr_lifecycle_policy` to keep only the last 10 images (saves storage cost).
4. Add outputs for the repository URLs in `outputs.tf`.
5. Log in, build, push (replace the registry with your own account id):
   ```bash
   aws ecr get-login-password --region ap-southeast-2 | docker login --username AWS --password-stdin $REGISTRY
   docker build -t $REGISTRY/task-app-backend:$TAG ./backend
   docker push $REGISTRY/task-app-backend:$TAG
   ```
6. Update the image names in your Deployments (or `values-aws.yaml`) to use ECR.

**You learn:** registry, image tags, scan on push, lifecycle rules.

---

### Step 6: CI/CD (GitHub Actions, free tier)

**What:** Every push builds the images, pushes them to ECR, and deploys.
**Where:** `.github/workflows/ci.yml` and `.github/workflows/deploy.yml` (these must be at the **root of the Git repo**, not inside this folder. Your repo root is `Nov2026_38_Pathnex`, so use `paths:` filters or `working-directory`).
**How:**

1. **CI workflow** (on pull request):
   - Backend: `bundle install`, run tests/lint.
   - Frontend: `npm ci`, `npm run build`.
   - `docker build` to check the Dockerfiles still work.
   - `helm lint`.
2. **CD workflow** (on merge to `main`):
   - Log in to AWS with **OIDC** (no long lived keys). Create an IAM role for GitHub with Terraform.
   - Build and push images to ECR, tag with the Git commit SHA.
   - Run `aws eks update-kubeconfig`, then `helm upgrade --install ... --set image.tag=$GITHUB_SHA`.
3. Store settings in **GitHub repository secrets / variables**. Never write keys in the YAML file.
4. Add `environment: production` with a manual approval for deploy.

Alternative: GitLab CI (free tier) does the same with `.gitlab-ci.yml`. Pick one first, try the other later.

**You learn:** pipelines, OIDC login, image tagging by SHA, safe deploys.

---

### Step 7: ElastiCache (Redis on AWS)

**What:** Replace the Redis pod with managed Redis from AWS. Do this **last** because it costs money.
**Where:** New file `terraform/elasticache.tf`, small changes in the ConfigMap/values.
**How:**

1. Create `aws_elasticache_subnet_group` using your **private** subnets.
2. Create `aws_security_group` that allows port 6379 **only from the EKS node security group** (same idea as your `rds_from_eks_nodes` rule).
3. Create `aws_elasticache_replication_group` (or `aws_elasticache_cluster`) with the smallest node (`cache.t4g.micro`), 1 node for practice.
4. Output the endpoint. Set `REDIS_URL` to `redis://<endpoint>:6379/0` (use `rediss://` if you turn on in-transit encryption).
5. Remove `k8s/11_redis_deployment.yml` (or turn it off in Helm with `redis.enabled=false`).
6. Check: `/ready` is 200, tasks still move `pending -> processing -> done`.
7. Run `terraform destroy` when done.

**You learn:** managed services, security groups between layers, why Redis moved out of the cluster.

---

## 4. Bonus tools (also free, not in the README)

Do these only after the main plan. They fit this app well.

| Tool | Where to use it | Short how-to |
|------|-----------------|--------------|
| **kind / minikube** | Free local Kubernetes for Steps 1 to 4 | `kind create cluster`, then apply or `helm install` |
| **Kustomize** (built in `kubectl -k`) | Different settings for local vs AWS without Helm | `k8s/base` + `k8s/overlays/{local,aws}` |
| **Prometheus + Grafana** (Helm chart `kube-prometheus-stack`) | See CPU, memory, Sidekiq queue size | Install chart, port-forward Grafana, build a dashboard |
| **Loki** (logs) | Search Rails and Sidekiq logs in Grafana | Install `loki-stack` chart |
| **Trivy** | Scan images and Terraform for security issues | Add it as a step in CI |
| **tflint / checkov** | Check Terraform before apply | Run in CI on `terraform/` |
| **cert-manager** | Free HTTPS certificates for the Ingress | Install chart, create a `ClusterIssuer` (Let's Encrypt) |
| **Argo CD** | GitOps: cluster follows Git automatically | Install, point it at your Helm chart folder |
| **External Secrets Operator** | Read DB password from AWS Secrets Manager instead of `k8s/03_secret.yaml` | Install chart, create a `SecretStore` |

---

## 5. Practice checklist

Tick each box as you finish.

- [ ] Step 1: Probes added and tested (Redis down gives 503)
- [ ] Step 2: Helm chart installs, upgrades, and rolls back
- [ ] Step 3: HPA scales backend under load
- [ ] Step 4: KEDA scales Sidekiq by queue length
- [ ] Step 5: ECR repos created by Terraform, images pushed
- [ ] Step 6: CI builds on PR, CD deploys on merge
- [ ] Step 7: ElastiCache works, then `terraform destroy`
- [ ] Bonus: Prometheus + Grafana dashboard
- [ ] Bonus: Trivy scan in CI

## 6. Tips

- Make a Git branch per step (example: `step2-helm`). It is easy to undo.
- Run `terraform plan` and read it before every `apply`.
- Take short notes after each step: what broke, what fixed it. That is the real learning.
- If a step is too hard, do the local free version first, then repeat on AWS.
