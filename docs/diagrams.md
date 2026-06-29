# Architecture Diagrams

This file contains all diagrams referenced in the [README.md](../README.md). Each diagram is written in **Mermaid** syntax and can be rendered on [mermaid.live](https://mermaid.live), GitHub, or any Mermaid-compatible viewer.

---

## 1. Architecture Overview

```mermaid
graph TB
    subgraph "CI/CD Layer - GitHub Actions"
        CI_WF["CI Pipeline<br/>Lint (ruff) → Test (pytest) → Build → Push ECR"]
        CD_WF["CD Pipeline<br/>ArgoCD Sync → Promote/Abort Rollout"]
        TF_WF["Terraform Workflows<br/>Plan / Apply / Destroy"]
    end

    subgraph "AWS Cloud"
        subgraph "Region: us-east-1 / us-east-2"
            subgraph "Networking Layer"
                VPC["VPC<br/>CIDR: 10.x.0.0/16"]
                PUB_SUB["Public Subnets<br/>ALB Ingress"]
                PRIV_SUB["Private Subnets<br/>EKS Worker Nodes"]
                NAT["NAT Gateway"]
                IGW["Internet Gateway"]
            end

            subgraph "EKS Cluster - demo-app-{env}"
                subgraph "Platform Namespaces"
                    direction TB
                    ISTIO["Istio<br/>istio-system namespace<br/>Sidecar injection + mTLS"]
                    ARGOCD["Argo CD<br/>argocd namespace<br/>GitOps Controller"]
                    ROLLOUTS["Argo Rollouts<br/>argo-rollouts namespace<br/>Canary + Blue-Green controller"]
                    ALBC["AWS LB Controller<br/>kube-system namespace<br/>Ingress Provisioning"]
                    EXT_SEC["External Secrets<br/>external-secrets namespace<br/>ClusterSecretStore → Secrets Manager"]
                end

                subgraph "Monitoring Namespace"
                    PROM["Prometheus<br/>Metrics + Alertmanager"]
                    GRAFANA["Grafana<br/>Dashboards<br/>pw: Secrets Manager"]
                    LOKI["Loki<br/>Log Aggregation<br/>S3-backed"]
                end

                subgraph "Application Namespace: myapp"
                    direction LR
                    
                    subgraph "Frontend Rollout (Canary)"
                        FE_STABLE["frontend-stable<br/>Service (ClusterIP)"]
                        FE_CANARY["frontend-canary<br/>Service (ClusterIP)"]
                        FE_POD_V1["Frontend v1<br/>4 replicas<br/>+ Istio sidecar"]
                        FE_POD_V2["Frontend v2<br/>Canary pods<br/>+ Istio sidecar"]
                    end

                    subgraph "Backend Rollout (Blue-Green)"
                        BE_ACTIVE["backend-active<br/>Service (ClusterIP)"]
                        BE_PREVIEW["backend-preview<br/>Service (ClusterIP)"]
                        BE_POD_V1["Backend v1<br/>Active pods<br/>+ Istio sidecar"]
                        BE_POD_V2["Backend v2<br/>Preview pods<br/>+ Istio sidecar"]
                    end
                end
            end

            subgraph "AWS Services"
                ECR_BE["ECR<br/>app-backend"]
                ECR_FE["ECR<br/>app-frontend"]
                S3_DATA["S3<br/>data-source bucket<br/>CSV file storage"]
                S3_REP["S3 Replication<br/>Cross-region sync<br/>us-east-1 → us-east-2"]
                IAM_IRSA["IAM Roles<br/>IRSA for Service Accounts"]
                IAM_S3REP["IAM Role<br/>S3 Replication"]
                SM["Secrets Manager<br/>grafana-admin-{env}"]
                R53["Route 53<br/>DNS (production)"]
                ACM["ACM<br/>SSL/TLS (production)"]
            end

            WAF["AWS WAF<br/>WebACL<br/>Managed rules + Rate limit"]
            ALB["AWS ALB<br/>HTTPS :443<br/>WAF Association"]
        end
    end

    subgraph "Version Control"
        GIT["GitHub Repository<br/>my-devops-project"]
        BRANCHES["Branches<br/>dev | test | staging | perf | main"]
    end

    subgraph "External"
        USER["End User<br/>Browser"]
        DEV["Developer<br/>git push / workflow_dispatch"]
    end

    %% User Traffic Flow
    USER -->|"https://cloudnativeops.online"| ALB
    ALB -.->|"Associated"| WAF
    ALB -->|"ALB Ingress<br/>→ frontend-stable"| FE_STABLE
    FE_POD_V1 -->|"GET /api/data"| BE_ACTIVE
    BE_POD_V1 -->|"boto3 get_object()"| S3_DATA
    S3_DATA -.->|"Cross-region replication"| S3_REP
    IAM_S3REP -.->|"Trust Policy"| S3_REP

    %% GitOps Flow
    DEV -->|"git push"| GIT
    GIT -->|"Webhook / 3min Poll"| ARGOCD
    ARGOCD -->|"Sync manifests"| ROLLOUTS
    ARGOCD -->|"Sync manifests"| ALBC
    ARGOCD -->|"Sync manifests"| ISTIO
    ARGOCD -->|"Sync manifests"| EXT_SEC
    ARGOCD -->|"Sync manifests"| PROM
    ARGOCD -->|"Sync manifests"| GRAFANA
    ARGOCD -->|"Sync manifests"| LOKI

    %% Rollout Control Flow
    ROLLOUTS -.->|"controls canary<br/>(replica-weight)"| FE_STABLE
    ROLLOUTS -.->|"controls canary"| FE_CANARY
    ROLLOUTS -.->|"controls blue-green<br/>(selector swap)"| BE_ACTIVE
    ROLLOUTS -.->|"controls blue-green"| BE_PREVIEW

    %% Istio Sidecar Flow
    ISTIO -.->|"sidecar mTLS + metrics"| FE_POD_V1
    ISTIO -.->|"sidecar mTLS + metrics"| FE_POD_V2
    ISTIO -.->|"sidecar mTLS + metrics"| BE_POD_V1
    ISTIO -.->|"sidecar mTLS + metrics"| BE_POD_V2

    %% Monitoring Flow
    PROM -.->|"scrape (ServiceMonitor)"| FE_POD_V1
    PROM -.->|"scrape (ServiceMonitor)"| BE_POD_V1
    PROM -.->|"scrape (ServiceMonitor)"| ISTIO
    GRAFANA -.->|"datasource"| PROM
    GRAFANA -.->|"datasource"| LOKI
    GRAFANA -.->|"admin password"| EXT_SEC
    EXT_SEC -.->|"GetSecretValue"| SM

    %% CI/CD Flow
    CI_WF -->|"docker push"| ECR_BE
    CI_WF -->|"docker push"| ECR_FE
    CI_WF -->|"Update Helm values + commit"| GIT
    CD_WF -->|"argocd app sync"| ARGOCD
    CD_WF -->|"kubectl-argo-rollouts promote"| ROLLOUTS

    %% IaC Flow
    TF_WF -->|"terraform apply"| VPC
    TF_WF -->|"terraform apply"| ECR_BE
    TF_WF -->|"terraform apply"| S3_DATA
    TF_WF -->|"terraform apply"| IAM_IRSA
    TF_WF -->|"terraform apply"| IAM_S3REP
    TF_WF -->|"terraform apply"| ACM
    TF_WF -->|"terraform apply"| R53
    TF_WF -->|"terraform apply"| WAF
    TF_WF -->|"terraform apply"| SM

    %% IRSA Trust
    IAM_IRSA -.->|"OIDC Trust"| BE_POD_V1
    IAM_IRSA -.->|"OIDC Trust"| ALBC
    IAM_IRSA -.->|"OIDC Trust"| EXT_SEC

    %% Styling
    classDef aws fill:#FF9900,color:#000,stroke:#232F3E
    classDef k8s fill:#326CE5,color:#fff,stroke:#326CE5
    classDef cicd fill:#2088FF,color:#fff,stroke:#0366D6
    classDef git fill:#333,color:#fff,stroke:#666
    classDef user fill:#28A745,color:#fff,stroke:#1E7E34
    classDef security fill:#EF4444,color:#fff,stroke:#DC2626

    class VPC,PUB_SUB,PRIV_SUB,NAT,IGW,ALB,S3_DATA,S3_REP,ECR_BE,ECR_FE,IAM_IRSA,IAM_S3REP,R53,ACM,SM aws
    class ISTIO,ARGOCD,ROLLOUTS,ALBC,EXT_SEC,PROM,GRAFANA,LOKI,FE_STABLE,FE_CANARY,BE_ACTIVE,BE_PREVIEW k8s
    class CI_WF,CD_WF,TF_WF cicd
    class GIT,BRANCHES git
    class USER,DEV user
    class WAF security
```

---

## 2. Terraform Module Dependency Graph

```mermaid
graph TD
    ROOT["root.hcl<br/>Provider + Remote State"]

    subgraph "Environment Common"
        VPC_HCL["vpc.hcl"]
        EKS_HCL["eks.hcl"]
        ECR_HCL["ecr.hcl"]
        IAM_HCL["iam.hcl"]
        IAM_SA_HCL["iam-service-accounts.hcl"]
        S3_HCL["s3.hcl"]
        WAF_HCL["waf.hcl"]
        WAF_HCL["waf.hcl"]
        KMS_HCL["kms.hcl"]
        SM_HCL["secrets-manager.hcl"]
        ACM_HCL["acm.hcl"]
        R53_HCL["route53.hcl"]
        ARGOCD_HCL["argocd.hcl"]
    end

    subgraph "Environment Config"
        ENV["environment.hcl<br/>account_id + env name"]
        REGION["region.hcl<br/>aws_region (per region)"]
    end

    subgraph "Global Resources (per-environment)"
        IAM_ALB["IAM Role<br/>ALB Controller IRSA<br/><i>dev/global/iam/alb-controller</i>"]
        IAM_BE["IAM Role<br/>Backend S3 IRSA<br/><i>dev/global/iam/app-backend</i>"]
        IAM_ES["IAM Role<br/>External Secrets IRSA<br/><i>dev/global/iam/external-secrets</i>"]
        IAM_S3REP["IAM Role<br/>S3 Replication<br/><i>production/global/iam/s3-replication</i>"]
        R53_RES["Route53<br/>DNS Records<br/><i>production/global/route53</i>"]
    end

    subgraph "Regional Resources (us-east-1 / us-east-2)"
        VPC_RES["VPC<br/>Subnets + NAT + IGW"]
        EKS_RES["EKS Cluster<br/>Node Groups + Addons"]
        ECR_RES["ECR Repos<br/>app-backend + app-frontend"]
        ACM_RES["ACM<br/>SSL Certificates"]
        S3_RES["S3 Bucket<br/>data-source<br/>SSE-KMS encrypted"]
        KMS_RES["KMS Key<br/>alias/s3-{env}-{region}<br/>S3 + ECR + Secrets Manager"]
        WAF_RES["WAF WebACL<br/>Managed rules + Rate limit"]
        SM_RES["Secrets Manager<br/>Grafana admin password<br/>KMS encrypted"]
        ARGOCD_RES["Argo CD<br/>Helm Release"]
    end

    ENV --> ROOT
    REGION --> ROOT

    ROOT --> VPC_HCL
    ROOT --> EKS_HCL
    ROOT --> ECR_HCL
    ROOT --> IAM_HCL
    ROOT --> IAM_SA_HCL
    ROOT --> S3_HCL
    ROOT --> WAF_HCL
    ROOT --> KMS_HCL
    ROOT --> SM_HCL
    ROOT --> ACM_HCL
    ROOT --> R53_HCL
    ROOT --> ARGOCD_HCL

    VPC_HCL --> VPC_RES
    EKS_HCL -->|"depends_on: VPC"| EKS_RES
    ECR_HCL --> ECR_RES
    KMS_HCL --> KMS_RES

    IAM_SA_HCL -->|"depends_on: EKS (OIDC)"| IAM_ALB
    IAM_SA_HCL -->|"depends_on: EKS (OIDC)"| IAM_BE
    IAM_SA_HCL -->|"depends_on: EKS (OIDC)"| IAM_ES
    IAM_HCL --> IAM_S3REP
    KMS_RES -.->|"encrypts"| S3_RES
    KMS_RES -.->|"encrypts"| ECR_RES
    KMS_RES -.->|"encrypts"| SM_RES
    WAF_HCL --> WAF_RES
    SM_HCL --> SM_RES
    ACM_HCL --> ACM_RES
    R53_HCL -->|"depends_on: ACM"| R53_RES
    S3_HCL -->|"prod: depends_on IAM S3 Rep"| S3_RES
    ARGOCD_HCL -->|"depends_on: EKS"| ARGOCD_RES

    VPC_RES -.-> EKS_RES
    EKS_RES -.-> IAM_ALB
    EKS_RES -.-> IAM_BE
    EKS_RES -.-> IAM_ES
    EKS_RES -.-> ARGOCD_RES
    IAM_S3REP -.-> S3_RES
    ACM_RES -.-> R53_RES

    classDef input fill:#6F42C1,color:#fff
    classDef common fill:#D63384,color:#fff
    classDef global fill:#0DCAF0,color:#000
    classDef regional fill:#0D6EFD,color:#fff
    classDef security fill:#EF4444,color:#fff

    class ENV,REGION input
    class VPC_HCL,EKS_HCL,ECR_HCL,IAM_HCL,IAM_SA_HCL,S3_HCL,WAF_HCL,KMS_HCL,SM_HCL,ACM_HCL,R53_HCL,ARGOCD_HCL common
    class IAM_ALB,IAM_BE,IAM_ES,IAM_S3REP,R53_RES global
    class VPC_RES,EKS_RES,ECR_RES,ACM_RES,S3_RES,WAF_RES,SM_RES,ARGOCD_RES regional
    class KMS_RES security
```

---

## 3. ArgoCD App-of-Apps Tree

```mermaid
graph TD
    ROOT["Root Application<br/>gitops/dev/root.yaml<br/>directory.recurse: true"]

    ROOT -->|"sync-wave: -2"| ISTIO_APP["istio<br/>Chart: istio/base + istiod (1.24.2)<br/>Namespace: istio-system"]
    ROOT -->|"sync-wave: -1"| ROLLOUTS_APP["argo-rollouts<br/>Chart: argo-rollouts (2.37.0)<br/>Namespace: argo-rollouts"]
    ROOT -->|"sync-wave: -1"| ALB_APP["alb-controller<br/>Chart: aws-load-balancer-controller (1.7.2)<br/>Namespace: kube-system"]
    ROOT -->|"sync-wave: -1"| ES_APP["external-secrets<br/>Chart: external-secrets (0.15.0)<br/>Namespace: external-secrets"]
    ROOT -->|"sync-wave: -1"| MON_APP["monitoring<br/>Chart: kube-prometheus-stack (67.0.0)<br/>Namespace: monitoring"]
    ROOT -->|"sync-wave: 0"| LOKI_APP["loki<br/>Chart: loki (6.28.0)<br/>Namespace: monitoring"]
    ROOT -->|"sync-wave: 0"| GF_ES_APP["grafana-external-secret<br/>Path: gitops/.../resources/<br/>Namespace: monitoring"]

    ROOT -->|"sync-wave: 1"| BE_APP["backend<br/>Chart: helm-charts/backend<br/>Namespace: myapp<br/>Values: gitops/dev/backend/values.yaml"]
    ROOT -->|"sync-wave: 1"| FE_APP["frontend<br/>Chart: helm-charts/frontend<br/>Namespace: myapp<br/>Values: gitops/dev/frontend/values.yaml"]

    ISTIO_APP --> ISTIO_KIND["Kubernetes Resources<br/>├─ Istio base CRDs<br/>├─ Istiod deployment<br/>└─ Sidecar injector"]
    ROLLOUTS_APP --> ROLLOUT_KIND["Kubernetes Resources<br/>├─ Deployment (controller)<br/>├─ Service (dashboard)<br/>└─ CRDs"]
    ALB_APP --> ALB_KIND["Kubernetes Resources<br/>├─ Deployment<br/>├─ ServiceAccount (IRSA)<br/>└─ ClusterRole"]
    ES_APP --> ES_KIND["Kubernetes Resources<br/>├─ External Secrets operator<br/>├─ ClusterSecretStore (AWS SM)<br/>└─ ServiceAccount (IRSA)"]
    MON_APP --> MON_KIND["Kubernetes Resources<br/>├─ Prometheus<br/>├─ Grafana<br/>├─ Alertmanager<br/>├─ kube-state-metrics<br/>└─ node-exporter"]
    LOKI_APP --> LOKI_KIND["Kubernetes Resources<br/>├─ Loki (SingleBinary)<br/>├─ S3 bucket backend<br/>└─ ServiceMonitor"]
    GF_ES_APP --> GF_ES_KIND["Kubernetes Resources<br/>├─ ExternalSecret → grafana-admin-secret<br/>└─ SecretStore → aws-secrets-manager"]

    BE_APP --> BE_KIND["Kubernetes Resources<br/>├─ Rollout (Blue-Green)<br/>├─ Service (active)<br/>├─ Service (preview)<br/>├─ ServiceAccount (IRSA)<br/>├─ HPA<br/>└─ Istio sidecar"]

    FE_APP --> FE_KIND["Kubernetes Resources<br/>├─ Rollout (Canary)<br/>├─ Service (stable)<br/>├─ Service (canary)<br/>├─ Ingress (ALB → Istio)<br/>├─ ServiceAccount<br/>├─ HPA<br/>└─ Istio sidecar"]

    MON_KIND -.->|"scrape"| FE_KIND
    MON_KIND -.->|"scrape"| BE_KIND
    MON_KIND -.->|"scrape"| ISTIO_KIND
    GF_ES_KIND -.->|"grafana-admin"| MON_KIND

    classDef root fill:#D63384,color:#fff
    classDef platform fill:#6F42C1,color:#fff
    classDef app fill:#0D6EFD,color:#fff
    classDef k8s fill:#198754,color:#fff

    class ROOT root
    class ISTIO_APP,ROLLOUTS_APP,ALB_APP,ES_APP,MON_APP,LOKI_APP,GF_ES_APP platform
    class BE_APP,FE_APP app
    class ISTIO_KIND,ROLLOUT_KIND,ALB_KIND,ES_KIND,MON_KIND,LOKI_KIND,GF_ES_KIND,BE_KIND,FE_KIND k8s
```

---

## 4. CI/CD Pipeline Flow

```mermaid
sequenceDiagram
    actor Dev as Developer
    participant Git as GitHub
    participant CI as CI Pipeline
    participant ECR as AWS ECR
    participant CD as CD Pipeline
    participant ArgoCD as Argo CD
    participant K8s as EKS Cluster

    Note over Dev, K8s: === CI: Build & Push ===

    Dev->>Git: git push (dev / test branch)
    Git->>CI: Trigger workflow

    par App Matrix
        CI->>CI: Lint backend (ruff)
        CI->>CI: Test backend (pytest)
        CI->>CI: Build backend Docker image
        CI->>ECR: Push app-backend:{sha} + {timestamp}
    and
        CI->>CI: Lint frontend (ruff)
        CI->>CI: Test frontend (pytest)
        CI->>CI: Build frontend Docker image
        CI->>ECR: Push app-frontend:{sha} + {timestamp}
    end

    CI->>Git: Update Helm values with new tag + commit

    Note over Dev, K8s: === CD: Deploy ===

    Dev->>Git: workflow_dispatch (staging / perf / production)
    Git->>CD: Trigger CD workflow

    CD->>CD: aws eks update-kubeconfig
    CD->>ArgoCD: argocd app sync {app}
    ArgoCD->>K8s: Apply manifests from Git

    alt Backend (Blue-Green)
        K8s->>K8s: Create preview pods (v2)
        K8s->>K8s: Wait for health checks
        CD->>K8s: kubectl-argo-rollouts promote backend
        K8s->>K8s: Swap active ↔ preview
        K8s->>K8s: Scale down old pods (30s delay)
    else Frontend (Canary)
        K8s->>K8s: Create canary pods (v2)
        K8s->>K8s: 25% traffic → ALB weight shift
        K8s->>K8s: Manual gate (pause) — CD workflow decides
        K8s->>K8s: 100% traffic → promoted
    end

    Note over Dev, K8s: === Done ===
```

---

## 5. Progressive Delivery Strategy Comparison

```mermaid
graph LR
    subgraph "Backend: Blue-Green Strategy"
        direction TB
        BE_STEP1["Step 1: Deploy v2<br/>as Preview"]
        BE_STEP2["Step 2: Validate<br/>preview pods"]
        BE_STEP3["Step 3: Promote<br/>swap active ↔ preview"]
        BE_STEP4["Step 4: Scale down<br/>old pods (30s delay)"]

        BE_STEP1 --> BE_STEP2 --> BE_STEP3 --> BE_STEP4
        
        BE_NOTE["✅ Zero-downtime cutover<br/>✅ Instant rollback (swap back)<br/>⚠️ Double resources during rollout"]
    end

    subgraph "Frontend: Canary Strategy (Production)"
        direction TB
        FE_STEP1["Step 1: Deploy v2<br/>25% canary weight"]
        FE_STEP2["Step 2: Validate<br/>ALB traffic routing<br/>Manual gate (pause)"]
        FE_STEP3["Step 3: Promote<br/>100% weight<br/>dynamicStableScale"]
        FE_STEP4["Step 4: Scale down<br/>old pods removed"]

        FE_STEP1 --> FE_STEP2 --> FE_STEP3 --> FE_STEP4

        FE_NOTE["✅ ALB-level weight shifting<br/>✅ dynamicStableScale saves resources<br/>⚙️ Manual promotion via CD workflow"]
    end

    classDef blue fill:#0D6EFD,color:#fff
    classDef canary fill:#FD7E14,color:#fff
    classDef note fill:#F8F9FA,color:#333,stroke:#CCC

    class BE_STEP1,BE_STEP2,BE_STEP3,BE_STEP4 blue
    class FE_STEP1,FE_STEP2,FE_STEP3,FE_STEP4 canary
    class BE_NOTE,FE_NOTE note
```

---

## 6. Environment Promotion Path

```mermaid
graph LR
    DEV["dev<br/>Branch: dev<br/>CI: push → auto<br/>Rollout: auto-promote"]
    TEST["test<br/>Branch: test<br/>CI: push → auto<br/>Rollout: auto-promote"]
    STAGING["staging<br/>Branch: staging<br/>CI: PR merge → trigger<br/>Rollout: auto-promote"]
    PERF["perf<br/>Branch: perf<br/>CI: PR merge → trigger<br/>Rollout: auto-promote"]

    PROD_EAST1["production<br/>us-east-1 (Primary)<br/>Branch: main<br/>CI: auto<br/>Rollout: manual-promote"]
    PROD_EAST2["production<br/>us-east-2 (DR)<br/>Branch: main<br/>CI: auto<br/>Rollout: manual-promote"]

    DEV -->|"Promote"| TEST
    TEST -->|"Promote"| STAGING
    STAGING -->|"Promote"| PERF
    PERF -->|"Release"| PROD_EAST1
    PERF -->|"Release"| PROD_EAST2

    classDef dev fill:#198754,color:#fff
    classDef mid fill:#FD7E14,color:#fff
    classDef prod fill:#DC3454,color:#fff

    class DEV,TEST dev
    class STAGING,PERF mid
    class PROD_EAST1,PROD_EAST2 prod
```

---

## 7. Quick Start Flow

```mermaid
flowchart TD
    START["🚀 Starting Point"]
    CLONE["1. Clone Repository<br/>git clone ..."]
    TOOLS["2. Install Tools<br/>mise install"]
    INFRA["3. Provision Infrastructure<br/>terragrunt run-all apply"]
    KUBECTL["4. Configure kubectl<br/>aws eks update-kubeconfig"]
    ARGOCD["5. Access ArgoCD<br/>kubectl port-forward"]
    GITOPS["6. Bootstrap GitOps<br/>kubectl apply -f root.yaml"]
    DEPLOY["7. Deploy Apps<br/>Push to branch or manual build"]
    DONE["✅ Done!<br/>App is live"]

    START --> CLONE
    CLONE --> TOOLS
    TOOLS --> INFRA
    INFRA --> KUBECTL
    KUBECTL --> ARGOCD
    ARGOCD --> GITOPS
    GITOPS --> DEPLOY
    DEPLOY --> DONE

    INFRA_DETAIL["Creates:<br/>• VPC + Subnets<br/>• EKS Cluster<br/>• ECR Repos<br/>• S3 Buckets<br/>• IAM Roles<br/>• ArgoCD"]
    ARGOCD_DETAIL["Syncs:<br/>• ALB Controller<br/>• Argo Rollouts<br/>• Backend App<br/>• Frontend App"]

    INFRA -.-> INFRA_DETAIL
    GITOPS -.-> ARGOCD_DETAIL

    classDef step fill:#0D6EFD,color:#fff
    classDef detail fill:#F8F9FA,color:#333,stroke:#CCC
    classDef done fill:#198754,color:#fff

    class CLONE,TOOLS,INFRA,KUBECTL,ARGOCD,GITOPS,DEPLOY step
    class INFRA_DETAIL,ARGOCD_DETAIL detail
    class DONE done
```

---

## How to Render

These diagrams use **Mermaid** syntax. You can render them in any of the following ways:

1. **GitHub**: Mermaid diagrams render natively in GitHub markdown files
2. **VS Code**: Install the "Markdown Preview Mermaid Support" extension
3. **[mermaid.live](https://mermaid.live)**: Paste any diagram code to render and export as PNG/SVG
4. **CLI**: `npx @mermaid-js/mermaid-cli -i diagram.mmd -o diagram.png`
