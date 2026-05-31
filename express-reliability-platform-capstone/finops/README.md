# FinOps — Cost Visibility & Guardrails

Cost is a reliability concern: an unbounded bill is its own incident. This module gives the platform
three things — **see** cost, **visualize** it, and **guard** it with a budget alarm.

| File | What it does |
|---|---|
| `check_costs.py` | Pulls AWS Cost Explorer data (boto3 → AWS CLI → sample fallback) and prints a ranked per-service report. |
| `visualize_costs.py` | Renders a cost breakdown as a terminal bar chart so hot-spots are obvious. |
| `setup_cost_alarm.sh` | Creates a monthly AWS budget with email alerts at 50/80/100% (imperative path). |
| `terraform/budget/` | The reviewable, version-controlled budget guardrail (preferred path). |

## Quick start

```sh
# See costs (no credentials needed for the sample)
python3 finops/check_costs.py --sample
python3 finops/check_costs.py --days 7          # real data once AWS is configured

# Visualize
python3 finops/visualize_costs.py --sample

# Guardrail: budget + email alerts (dry-run first)
DRY_RUN=1 ./finops/setup_cost_alarm.sh 200 you@example.com
./finops/setup_cost_alarm.sh 200 you@example.com express-platform-budget

# Or via Terraform (preferred)
terraform -chdir=finops/terraform/budget init
terraform -chdir=finops/terraform/budget apply
```

> Tag-based cost filtering requires the tag keys to be activated as **Cost Allocation Tags** in the
> AWS Billing console; activation can take ~24h to back-fill historical spend.
