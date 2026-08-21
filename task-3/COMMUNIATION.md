# Client Communication Cadence

| Phase | Timeline | Deliverable | Owner |
|---|---|---|---|
| Discovery | Day 1-2 | Detailed finding analysis, risk assessment | Security Lead |
| Emergency Fixes | Day 2-3 | Critical fixes (RDS public, SSH open, S3 public) | Infrastructure Team |
| High Priority | Day 3-7 | IAM lockdown, CloudTrail enablement | Security Lead |
| Patching | Day 7-14 | SSM patching rollout, verification | DevOps Team |
| Validation | Day 14-21 | Re-scan with Inspector/Security Hub | QA/Compliance |
| Closure Report | Day 21 | Executive summary, evidence collection | Project Lead |