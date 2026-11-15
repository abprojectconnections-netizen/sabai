# 0004 — Open decisions for Legal, Finance and the PSP

Status: **waiting on people, not on engineering.** Each row is something the code already supports behind a switch or a seeded
proposal. Nothing here goes live until the owner answers; the "proposed default" column is what the code does today.

| # | Decision | Owner | Proposed default (what the code does now) | Where it lives |
|---|----------|-------|-------------------------------------------|----------------|
| 1 | Who is the legal issuer of the tax invoice for a partner's sale (platform as agent, or the partner)? | Legal + Accounting | Seller of record = partner; **issuing is blocked** until an issuer is approved | `tax_documents` issuer-gate trigger, `legal_entities` |
| 2 | VAT treatment of listed prices (included or added) and the rate per category | Accounting | `vat_included = UNVERIFIED`; no tax is computed | `tax_rates`, price snapshot |
| 3 | Wording of the consent a customer gives to receive a refund as wallet credit | Legal | **Wallet refunds are refused** until a legally approved, effective wording exists | `consent_versions`, `wallet_consents` |
| 4 | Retention period per document class | Legal + Accounting | Only TAX_DOCUMENT = 5 years is approved; others are unset | `retention_policies` |
| 5 | Approval matrix for refunds | Finance + CFO | PROPOSAL: auto ≤ 3,000; refund officer ≤ 5,000; finance manager ≤ 50,000; above that two approvers including CFO | `approval_limits` |
| 6 | Free-cancellation window and refund percentage by policy | Product + Finance | 48 hours before service, full refund of the amount paid | `terms_json` in each booking's price snapshot |
| 7 | Payment hold window | Product | 15 minutes | `booking.Create`, worker `expire-holds` |
| 8 | Platform service fee charged to customers | Finance | None | pricing rules |
| 9 | Commission: default rate, category rates, precedence, mixed-category bookings | Finance | 5% default; PARTNER > CATEGORY > DEFAULT; a booking with mixed categories uses PARTNER/DEFAULT | `commission_policies`, `settlement.resolvePolicy` |
| 10 | Refund after settlement: does the partner return commission, and how | Finance | Partner returns the refunded share of base and commission at the original rate, netted into the next batch; a batch that would go negative is refused and carries the reversal forward | `settlement.reversalCandidates` |
| 11 | Settlement cadence and reconciliation window | Finance | Weekly (Tuesday), 7-day window after the last service date; batches are prepared by a named person | `partner_contracts`, `settlement.Build` |
| 12 | Who may prepare, review and approve a settlement | Finance + Security | Preparer, reviewer and approver must be three different people | settlement checks, DB CHECK |
| 13 | "High risk" partner definition (blocks auto-approval) | Risk | Partner `risk_level = HIGH` | `refund.Create` |
| 14 | Payment service provider choice, credentials and sandbox | Finance + Engineering | Mock provider only | `payment.Provider` |
| 15 | Go-live approvals | PSP, Legal, Accounting, Security | A real provider or live supplier needs all four recorded; otherwise the service refuses to start it | `go_live_approvals`, `safety.Check` |
| 16 | Can the wallet pay for new bookings, or stay refund-credit only | Legal + Finance | Refund credit only: no top-up, transfer, withdrawal or checkout use | wallet module, web checkout |

Engineering follow-ups that unlock once an answer exists: tax-document generation and PDF (needs 1, 2, 4), wallet as a checkout method
(needs 3 and 16), automatic provider statement fetching (needs 14), real-provider webhooks and signatures (needs 14).
