# Cost Tagging Strategy for Multi-Client Consultancy

## Overview

In a multi-client consultancy environment, effective tagging is essential for accurate showback and invoicing. It enables the consultancy to clearly attribute cloud consumption to the correct client, project, environment, and internal cost center.

To achieve this, we recommend a structured approach based on the combination of a Resource Group and a Cost Center model. This approach provides both operational clarity and financial accountability, while remaining scalable as the consultancy grows.

---

## Recommended Tagging Model

The most effective model is to apply a consistent set of tags to all cloud resources so that each item can be mapped to its owning client, engagement, and internal billing structure.

### Mandatory Tag Keys and Recommended Values

| Tag Key | Purpose | Example Values |
| --- | --- | --- |
| `ClientID` | Identifies the end-customer or client associated with the resource. | `client-ace-corp`, `client-beta-inc` |
| `Project` | Identifies the specific project, engagement, or delivery initiative. | `migration-q4`, `data-pipeline-v2` |
| `Environment` | Distinguishes between dev, staging, prod, and sandbox workloads. | `prod`, `staging`, `dev`, `sandbox` |
| `CostCenter` | Identifies the internal finance code used for cost allocation. | `cc-1001`, `cc-1002` |
| `AutoShutdown` | Enables automated shutdown policies for non-production resources outside working hours. | `true`, `false` |
| `Owner` | Identifies the engineer or team responsible for the resource. | `john.doe@nimbustech.com` |

---

## Why This Model Works

This tagging strategy is designed to support both operational management and commercial reporting.

- It helps allocate infrastructure costs back to the correct client.
- It supports showback and invoicing with clear ownership and accountability.
- It separates technical environments (dev, staging, prod) from cost allocation structures.
- It enables automation for non-production resource control, such as scheduled shutdowns.
- It provides a consistent framework that can be applied across multiple client engagements.

---

## Suggested Governance Model

To keep the tagging framework enforceable and consistent, the consultancy should apply the following governance rules:

1. Every relevant resource must include the mandatory tags listed above.
2. Tag values should follow a naming convention that is standardized across all engagements.
3. Validation checks should run regularly to identify non-compliant or missing tags.
4. Cost reports should be grouped by `ClientID`, `Project`, and `CostCenter` for budgeting and invoice generation.
5. Automation should be used to detect drift and correct tagging issues before billing cycles close.

