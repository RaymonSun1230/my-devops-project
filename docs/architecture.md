# Architecture & Infrastructure

> Part of [My DevOps Project](../README.md) — detailed documentation.

---

## Application Stack

The demo application is a **CSV data viewer** with a Flask backend reading from S3 and a Flask frontend rendering results:

| Component | Language | Framework | Port | Description |
|-----------|----------|-----------|------|-------------|
| **Frontend** | Python 3.12 | Flask + Jinja2 | 7000 | Renders CSV data as an HTML table |
| **Backend** | Python 3.12 | Flask | 7001 | Reads CSV from S3 via boto3, exposes `/api/data` |

**Data flow:** User → ALB → Frontend → Backend → S3

Both services expose `/health` endpoints for Kubernetes liveness & readiness probes. The backend uses **IRSA** (IAM Roles for Service Accounts) to access S3 without hardcoded credentials.

---


## Platform Architecture

The platform is designed for **5 environments** across **2 AWS regions** (us-east-1, us-east-2). Every layer — from networking to application deployment — is defined as code and orchestrated through Git.

```
Route53 → ACM (SSL) → ALB + WAF (WebACL) → EKS
                                            ├── istio-system ns     (Istio service mesh 1.24)
                                            ├── argocd ns           (Argo CD)
                                            ├── argo-rollouts ns    (Progressive Delivery)
                                            ├── external-secrets ns (Secrets Manager bridge)
                                            ├── monitoring ns       (Prometheus + Grafana + Loki)
                                            ├── kube-system ns      (AWS LB Controller)
                                            └── myapp ns           (with Istio sidecar)
                                                 ├── Frontend (Flask, Canary)
                                                 └── Backend  (Flask, Blue-Green) → S3
```

### AWS Components

| Component | Purpose |
|-----------|---------|
| **VPC** | Network isolation, public + private subnets, NAT Gateway |
| **ALB** | Internet-facing ingress, managed by AWS LB Controller |
| **WAF** | WebACL with managed rule groups, rate limiting, SQLi protection (production) |
| **EKS** | Kubernetes 1.35, ARM64 (t4g.small), managed node groups |
| **ECR** | Container registry for app-backend & app-frontend images |
| **S3** | CSV data storage per environment, Terraform remote state; cross-region replication (production) |
| **Secrets Manager** | Grafana admin password, auto-generated per environment |
| **IAM (IRSA)** | Pod-level AWS access via OIDC — no static credentials |
| **IAM (S3 Replication)** | Cross-region replication role (production, us-east-1 → us-east-2) |
| **ACM** | SSL/TLS certificates for custom domain (production only) |
| **Route53** | DNS routing, health checks, failover (production only) |

### Kubernetes Namespaces

| Namespace | Components | Purpose |
|-----------|-----------|---------|
| `argocd` | Argo CD | GitOps controller, App-of-Apps root |
| `argo-rollouts` | Argo Rollouts controller + dashboard | Progressive delivery |
| `istio-system` | Istio (base + istiod) | Service mesh — sidecar injection, mTLS, traffic management |
| `external-secrets` | External Secrets Operator + ClusterSecretStore | Bridge AWS Secrets Manager → K8s Secrets |
| `monitoring` | Prometheus + Grafana + Loki + Alertmanager | Metrics collection, dashboards, log aggregation, alerting |
| `kube-system` | AWS Load Balancer Controller | ALB/NLB provisioning from Ingress |
| `myapp` | Backend + Frontend (with Istio sidecar) | Application workloads |

---

## Environments

| Environment | Git Branch | CI Trigger | GitOps Update | Rollout Promotion |
|-------------|-----------|------------|---------------|-------------------|
| **dev** | `dev` | Push → auto | Direct push | Auto-promote |
| **test** | `test` | Push → auto | Direct push | Auto-promote |
| **staging** | `staging` | Manual (workflow_dispatch) | Pull request | Auto-promote |
| **perf** | `perf` | Manual (workflow_dispatch) | Pull request | Auto-promote |
| **production** | `main` | Manual (workflow_dispatch) | Pull request | Manual-promote |

### Promotion Path

```
dev → test → staging → perf → production
                                ├── us-east-1 (primary)
                                └── us-east-2 (DR)
```

### Multi-Region Design

Production is designed for multi-region deployment, with independent GitOps management per region:

```
gitops/production/
├── us-east-1/    # Primary region
└── us-east-2/    # DR/secondary region
```

![Architecture Diagram]
