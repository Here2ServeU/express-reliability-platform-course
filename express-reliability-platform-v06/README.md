# Express Reliability Platform V6 — Infrastructure as Code Discipline

## 1) Version Purpose

Standardize Terraform usage across environments with clear state, module, and bootstrap patterns.

## 2) Chapters Covered

- Chapter 13: Terraform Foundations (state, backend, modules, environments)

## 3) What You Will Build

- A disciplined IaC workflow for `live` and `shared` environments.
- A reusable module-driven infrastructure layout.

## 4) Architecture Diagram (Mermaid)

```mermaid
flowchart TD
    Bootstrap[bootstrap infra] --> Backend[Terraform backend/state]
    Backend --> Shared[shared environment]
    Backend --> Live[live environment]
    Shared --> Modules[modules: vpc/iam/eks/alb]
    Live --> Modules
```

## 5) Project Structure

```text
express-reliability-platform-v06/
├── environments/
│   ├── live/
│   └── shared/
├── infrastructure/
│   └── bootstrap/
├── modules/
│   ├── alb/
│   ├── eks/
│   ├── iam/
│   └── vpc/
├── scripts/
│   └── terraform_init_apply.sh
└── README.md
```

## 6) Run Steps

1. Configure AWS credentials and region.
2. Bootstrap remote state resources (if required by your backend setup).
3. Apply shared environment first.
4. Apply live environment next.
5. Use helper script:

   ```sh
   ./scripts/terraform_init_apply.sh
   ```

## 7) Validation Checklist

- [ ] Remote state backend is reachable and locked correctly.
- [ ] `terraform validate` and `terraform plan` run cleanly.
- [ ] Module outputs are wired correctly between environments.
- [ ] Re-running apply is idempotent (no unexpected drift).

## 8) Troubleshooting

- State lock stuck: release lock only after confirming no active Terraform run.
- Backend init errors: verify bucket/table/permissions in bootstrap resources.
- Module mismatch: verify variable names and output references.

## 9) Cleanup

- Destroy lab resources in reverse dependency order (`live` before `shared`).

## 10) Next Version Preview

In V7, you operationalize reliability with runbooks, incident response workflows, and disaster recovery habits.


