# CI/CD Pipelines

> Part of [My DevOps Project](../README.md) — detailed documentation.

---

## CI Pipeline (`ci.yaml`)

The pipeline runs 3 sequential stages after resolving the target branch:

```
Stage 1: Lint & Test (matrix)   Stage 2: Build & Push (matrix)   Stage 3: Update GitOps
+----------------------------+ +----------------------------+ +-------------------------+
| Backend: ruff -> pytest    | | Backend:                    | | dev / test:             |
| Frontend: ruff -> pytest   | |  Docker Build -> Trivy scan | |  direct commit          |
+----------------------------+ |  -> Push to ECR             | | staging / perf / main:  |
                               | Frontend: (same)            | |  create Pull Request    |
                               +----------------------------+ +-------------------------+
```

### Triggers

| Trigger | Branches | Path Filter |
|---------|----------|-------------|
| **Auto (push)** | `dev`, `test` | `app/backend/**` or `app/frontend/**` |
| **Manual (workflow_dispatch)** | All environments | None |

### Image Tag

Each build produces a single tag pushed to ECR:

- `v{YYYYMMDD}-{sha7}` — human-readable + traceable to commit

Example: `v20260608-69354f2`

### Key Pipeline Details

**1. Resolve Branch** — Determines the target branch based on trigger:
- Push event -> uses the branch being pushed
- `workflow_dispatch` -> maps environment to branch (`production` -> `main`, others -> env name)

**2. Lint & Test** — Runs in parallel for backend and frontend via `strategy.matrix`:
- `ruff check` for linting
- `pytest` for unit tests (continues if no tests found)

**3. Build & Push** — Builds and pushes Docker images:
- **Single tag**: `v{YYYYMMDD}-{sha7}`, platform: `linux/arm64`
- **Trivy scan**: Blocks push on CRITICAL/HIGH vulnerabilities
- Uses GitHub Actions cache and OIDC authentication to ECR

**4. Update GitOps Values** — Updates image tags in `gitops/`:
- **dev / test**: Direct commit to branch via `git-auto-commit-action`
- **staging / perf / main**: Creates a Pull Request via `create-pull-request`

### Independent Builds

Backend and Frontend can be selectively enabled for manual runs:

```yaml
inputs:
  build_frontend: true
  build_backend:  true
```

Only selected apps are built. On push events, both are always built.

---

## CD Pipeline (`cd.yaml`)

Triggered **only via `workflow_dispatch`** (manual).

### Actions

| Action | Description |
|--------|-------------|
| **deploy** | Install -> ArgoCD sync -> Wait for pods -> Promote rollout |
| **abort** | Install -> Abort rollout (revert to stable) |

### Inputs

```yaml
inputs:
  action:        [deploy, abort]
  environment:   [dev, test, staging, perf, production]
  app:           [backend, frontend]
  aws_region:    [us-east-1, us-east-2]
  cluster:       [demo-app]
```

### Workflow Stages

**`install` job** (always runs first):
1. Configure AWS OIDC credentials
2. Download `kubectl-argo-rollouts` + `argocd` CLI (architecture-aware)
3. Configure `kubectl` via `aws eks update-kubeconfig`
4. Run `argocd app sync` (with `--timeout 300`)
5. Wait for new ReplicaSet pods to become ready (polls up to 5 min)

**`promote` job** (after `install`, only for `action: deploy`):
1. Download `kubectl-argo-rollouts` (architecture-aware)
2. Run `kubectl argo rollouts promote "${ROLLOUT}" -n "${NAMESPACE}"`
3. Wait for rollout to complete (`kubectl argo rollouts status --timeout 300s`)

**`abort` job** (instead of promote, only for `action: abort`):
1. Download `kubectl-argo-rollouts` (architecture-aware)
2. Run `kubectl argo rollouts abort "${ROLLOUT}" -n "${NAMESPACE}"`
3. Wait for rollback

### Production Approval Gate

Production requires an **approval gate** via `production-required-reviewers` environment before the promote job runs.

### AWS Authentication

```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::${{ vars.AWS_ACCOUNT_ID }}:role/github-actions-role
    aws-region: ${{ inputs.aws_region }}
```

---

## Infrastructure Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `terraform-apply.yaml` | `workflow_dispatch` | Apply Terragrunt changes |
| `terraform-destroy.yaml` | `workflow_dispatch` | Destroy infrastructure (gated) |
| `pr-terraform-plan.yaml` | PR opened | Run `terragrunt plan` on PR |

## Other Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `rollback.yaml` | `workflow_dispatch` | Roll back application to previous image version |

---

## Pipeline Summary

| Pipeline | Trigger | Environments | Key Steps |
|----------|---------|-------------|-----------|
| **CI** | Push (dev/test) + Manual (all) | All | Lint (ruff) -> Test (pytest) -> Build -> Trivy scan -> Push ECR -> Update gitops (commit or PR) |
| **CD** | Manual only | All | ArgoCD sync -> Wait for pods -> Rollout promote / abort |
| **Infra** | Manual / PR | All | Terragrunt plan -> (review) -> apply / destroy |
| **Rollback** | Manual | All | Revert to previous image tag |
