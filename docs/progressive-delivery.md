# Progressive Delivery (Argo Rollouts)

> Part of [My DevOps Project](../README.md) — detailed documentation.

---

## Overview

The project uses **Argo Rollouts** for zero-downtime deployments with two distinct strategies tailored to each workload's characteristics.

---

## Backend: Blue-Green

The backend is an API service where atomic cutover is preferred over gradual traffic shifting.

```
┌──────────────┐     ┌──────────────┐
│  Active Svc  │     │ Preview Svc  │
│  (v1 pods)   │     │  (v2 pods)   │
│  100% traffic│     │  0% traffic  │
└──────────────┘     └──────────────┘
         │                   │
         ▼                   ▼
   Promote v2 → swap active/preview
```

| Detail | Value |
|--------|-------|
| **Active Service** | `backend-active` — receives all traffic |
| **Preview Service** | `backend-preview` — new version, validated before promotion |
| **Promotion** | Manual (`autoPromotionEnabled: false`) in higher environments; auto in dev |
| **Scale-down delay** | 30 seconds — keeps old pods alive for quick rollback |

### When to use Blue-Green

- API services where users shouldn't see mixed versions
- Stateful workloads that can't serve two versions simultaneously
- When instant rollback (swap back) is critical

---

## Frontend: Canary

The frontend uses canary deployment with **ALB-based traffic routing** to gradually shift real user traffic to new versions.

### Production Configuration

```
Step 1: Deploy v2        Step 2: Validate          Step 3: Promote         Step 4: Scale down
25% canary pods ──────▶  ALB routes 25% traffic ──▶ 100% weight ──────────▶ old pods removed
                         Manual gate (pause)        dynamicStableScale
```

| Step | Action | Detail |
|------|--------|--------|
| 1 | **Deploy v2** | 25% canary weight, new pods alongside stable |
| 2 | **Validate** | ALB traffic routing at 25%, manual gate (pause: {}) |
| 3 | **Promote** | 100% weight, dynamicStableScale scales stable down |
| 4 | **Scale down** | Old ReplicaSet removed |

```yaml
# gitops/production/us-east-1/frontend/values.yaml
rollout:
  dynamicStableScale: true
  canaryMaxSurge: 1
  canaryMaxUnavailable: 0
  canarySteps:
    - setWeight: 25
    - pause: {}
    - setWeight: 100
  trafficRouting:
    alb:
      ingress: frontend
      servicePort: 7000
```

Key production features:
- **ALB traffic routing** — weight shifts happen at the AWS ALB level, not just Kubernetes Services
- **`dynamicStableScale`** — stable ReplicaSet scales down as canary scales up, saving resources
- **Manual pause** (`pause: {}`) — indefinite pause at 25% until CD workflow promotes

### Chart Default (Non-Production)

```yaml
# helm-charts/frontend/values.yaml (default)
rollout:
  canarySteps:
    - setWeight: 10
    - pause: {duration: 2m}
    - setWeight: 50
    - pause: {duration: 2m}
    - setWeight: 100
    - pause: {duration: 30s}
```

Each environment can customize steps and pause durations — dev uses `pause: {duration: 0}` for instant promotion.

---

## Rollback & Escape Hatch

### Rollback via GitOps Pipeline

Rollback is done through the **`rollback.yaml`** GitHub Actions workflow — it reverts the image tag in Git and lets ArgoCD sync the change:

```bash
# Trigger via GitHub Actions UI:
# workflow: rollback.yaml
# inputs:
#   environment: production
#   app:          backend
#   tag:          v20260607-0215b15  # target image tag
```

**How it works:**
1. Updates `gitops/<env>/<app>/values.yaml` with the specified image tag
2. For **dev / test**: Direct commit to branch (auto-syncs via ArgoCD)
3. For **staging / perf / production**: Creates a Pull Request for review
4. After PR merge, run the **CD workflow** (`cd.yaml`) to sync ArgoCD

```yaml
# Example: rollback creates a PR for staging/perf/production
steps:
  - name: Revert image tag
    run: yq -i '.image.tag = "${TAG}"' gitops/${ENV}/${APP}/values.yaml

  - name: Create Pull Request
    uses: peter-evans/create-pull-request@v7
```

This GitOps-style rollback ensures every change — including rollbacks — is auditable via `git log`.

### Abort an In-Progress Rollout

To abort an in-progress rollout (during the canary pause or blue-green validation), use the CD pipeline with `action: abort`:

```bash
# Trigger via GitHub Actions UI:
# workflow: cd.yaml
# inputs:
#   action: abort
#   app:    frontend
```

This runs `kubectl argo rollouts abort` to immediately revert traffic to the stable version.

### Escape Hatch: Standard Deployment

When `rollout.enabled: false`, the Helm chart renders a standard `apps/v1 Deployment` instead of an `argoproj.io/v1alpha1 Rollout`. This provides:

- **Operational safety**: If Argo Rollouts is unhealthy, workloads keep running
- **Simplified debugging**: Standard `kubectl` commands work as expected
- **Gradual migration**: Teams can adopt progressive delivery incrementally

---

## ArgoCD CD Workflow Integration

```yaml
# .github/workflows/cd.yaml (simplified)
jobs:
  deploy:
    steps:
      - name: Configure kubectl
        run: aws eks update-kubeconfig --region $REGION --name $CLUSTER

      - name: Trigger ArgoCD sync
        run: |
          argocd login --core
          argocd app sync "${APP}" --timeout 300

      - name: Promote rollout
        run: |
          kubectl argo rollouts promote "${APP}" -n myapp
```

The CD workflow supports two actions:

| Action | Description |
|--------|-------------|
| **deploy** | Triggers ArgoCD sync + rollout promotion |
| **abort** | Aborts an in-progress rollout, reverting to stable |

![Rollout Strategies]
