# GitOps & Argo CD

> Part of [My DevOps Project](../README.md) — detailed documentation.

---

## App-of-Apps Pattern

The project follows the **App-of-Apps** pattern. A single **Root Application** per environment recursively discovers and syncs all child applications via `directory.recurse: true`.

### Sync Wave Ordering

```
Root Application
 └─ directory.recurse: true
     ├─ [Wave -1] argo-rollouts          (Platform — deploy first)
     ├─ [Wave -1] aws-load-balancer-controller
     ├─ [Wave 1]  backend                 (Apps — deploy after platform)
     └─ [Wave 1]  frontend
```

| Wave | Purpose | Components |
|------|---------|------------|
| **-1** | Platform infrastructure | Argo Rollouts, ALB Controller |
| **1** | Application workloads | Backend, Frontend |

### ArgoCD Sync Configuration

All applications use these sync policies:

```yaml
syncPolicy:
  automated:
    prune: true        # Remove resources not in Git
    selfHeal: true     # Auto-correct drift
  retry:               # Platform apps only
    limit: 3
    backoff:
      duration: 10s
      factor: 2
      maxDuration: 3m
  syncOptions:
    - CreateNamespace=true
```

---

## Multi-Source Applications

Each application uses Argo CD's **multi-source** feature to separate the Helm chart from environment-specific values:

```yaml
# gitops/dev/backend/application.yaml
spec:
  sources:
    - repoURL: https://github.com/.../my-devops-project.git
      targetRevision: dev
      path: helm-charts/backend                    # Chart source
      helm:
        valueFiles:
          - $values/gitops/dev/backend/values.yaml # Env-specific overrides
    - repoURL: https://github.com/.../my-devops-project.git
      targetRevision: dev
      ref: values                                   # Values source reference
```

### Value Override Hierarchy

```
helm-charts/<app>/values.yaml          # Chart defaults
    └── gitops/<env>/<app>/values.yaml  # Environment-specific overrides
```

This ensures:
- Chart templates are versioned once in `helm-charts/`
- Environment differences (image tags, replica counts, S3 buckets, subnets) live in `gitops/`
- No duplication — single source of truth per concern

---

## Environment Branch Mapping

| Environment | Git Branch | ArgoCD Target Revision |
|-------------|-----------|----------------------|
| **dev** | `dev` | `dev` |
| **test** | `test` | `test` |
| **staging** | `staging` | `staging` |
| **perf** | `perf` | `perf` |
| **production** | `main` | `main` |

Each branch has a corresponding `gitops/<env>/root.yaml` that Argo CD points to. Branch protection + manual dispatch gates higher environments.

---

## Helm Charts

### Backend Chart

| Feature | Implementation |
|---------|---------------|
| **Deployment Strategy** | Blue-Green via Argo Rollouts (active + preview services) |
| **Autoscaling** | Optional HPA (CPU/Memory) |
| **IRSA** | ServiceAccount with IAM role annotation for S3 access |
| **Health Checks** | `/health` endpoint (liveness + readiness) |

### Frontend Chart

| Feature | Implementation |
|---------|---------------|
| **Deployment Strategy** | Canary via Argo Rollouts (25% → 100%, ALB traffic routing, dynamicStableScale) |
| **Ingress** | ALB Ingress (internet-facing, IP target type) |
| **Autoscaling** | Optional HPA (CPU/Memory) |
| **Health Checks** | `/health` endpoint |

### ALB Controller Chart

| Feature | Implementation |
|---------|---------------|
| **Source** | Wrapper around upstream `aws-load-balancer-controller` (eks-charts 1.7.2) |
| **IRSA** | ServiceAccount with IAM role for ALB/NLB management |
| **Cluster Binding** | `clusterName`, `vpcId`, `region` |

### Escape Hatch

When `rollout.enabled: false`, each chart falls back to a standard Kubernetes `Deployment` — providing a safe operational escape hatch from progressive delivery for troubleshooting or emergency rollback.

![ArgoCD App-of-Apps]
