# Brazilian E-Commerce Analytics (dbt + DuckDB)

An end-to-end analytics engineering project on the public [Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) Brazilian e-commerce dataset (~100k orders, 9 related tables). It builds a tested, documented dbt project on a Kimball star schema and uses it to answer real business questions, with every insight framed as finding, evidence, impact, and recommendation.

The emphasis is on the things that matter in production analytics: correct grain, surrogate keys and referential tests, being honest about the data's limitations, and conclusions that separate correlation from causation.

## What this demonstrates

- A 3-layer dbt project: staging, intermediate, marts (20 models, 72 tests, 9 sources).
- A Kimball star schema: 3 dimensions and 2 fact tables at different grains, joined on surrogate keys with `relationships` tests enforcing referential integrity.
- Generic tests (`unique`, `not_null`, `accepted_values`, `relationships`, `dbt_utils` composite and range tests) plus a singular data-quality test run at WARN severity.
- Five analyses that go beyond description: a confounder-controlled delivery study, customer RFM segmentation with window functions, and seller and category revenue-concentration work.
- Deliberate scoping: documented decisions about what was *not* built, and why.

## The dataset and its limitations

Olist is a real marketplace export, so it is messy in the ways production data usually is. Three limitations are handled explicitly rather than ignored:

1. **No true cost or margin.** The data has `price`, `freight_value`, and `payment_value`, but no cost of goods. No profit or margin is computed; all revenue figures are gross merchandise value (item price).
2. **`customer_id` is per-order, not per-person.** Olist issues a new `customer_id` for every order. The real person is `customer_unique_id`. All person-level analysis (RFM, repeat rate) uses `customer_unique_id`; `customer_id` is treated as a per-order key only.
3. **Low repeat rate.** Only about 3% of customers order more than once, which bounds what retention and frequency analysis can claim. This is stated wherever it matters and drives a deliberate modelling decision (see Scope and Deliberate Exclusions).

## Architecture

![dbt lineage graph: sources to staging to intermediate to the star schema to analyses](docs/images/dag.png)

*Full project lineage rendered by `dbt docs`: green source tables, then `stg_olist__*`, the `int_*` aggregations, the star schema, and the analytical marts and analyses on the right.*

- **Staging** materialises as views, one model per source, with empirical type handling (for example, dates cast to `DATE` only where no row carries a time component).
- **Intermediate** holds order-grain aggregations of items, payments, and reviews, plus a geolocation model that deduplicates Brazil's zip-prefix coordinates to a single centroid per prefix.
- **Marts** materialise as tables. The star schema uses surrogate keys from `dbt_utils.generate_surrogate_key`; facts reference dimensions through those keys, with `relationships` tests verifying every key resolves. `fct_order_items` also carries a customer-to-seller great-circle (haversine) distance built from the deduplicated geolocation.

## Testing

- **Generic tests** on keys and categoricals: `unique` and `not_null` on every surrogate key, `accepted_values` on statuses and scores, `relationships` on all fact-to-dimension keys, and `dbt_utils.unique_combination_of_columns` for composite grains.
- **A singular data-quality test** (`tests/assert_payment_matches_order_value.sql`) reconciles each order's payment against item price plus freight. It runs at **WARN** severity because the mismatches are legitimate Brazilian payment mechanics (installment interest and vouchers), not ingestion errors. It surfaces them rather than failing the build.
- Dimensions are SCD Type 1 (overwrite). In production these would be snapshotted for SCD Type 2 history.

## Insights

All numbers are produced by the analyses in `/analyses`, which read the built marts.

### 1. Late delivery is associated with lower review scores

- **Finding:** missing the promised delivery date is associated with a sharp drop in review score, roughly 2.5 stars.
- **Evidence:** average review by delivery-vs-estimate bucket: early 4.29, on-time 4.04, 1 to 5 days late 2.99, 6 to 15 days late 1.74, 15+ days late 1.73. The drop is steady and sharpest at the on-time to slightly-late boundary. Arriving early beats arriving exactly on time.
- **Robustness:** the same drop holds within product categories, within weight bands, and within distance bands. Distance has a small effect of its own (about 0.1 star across the range), but lateness is roughly twenty times larger and survives all three controls. Association is defensible; causation is not claimed (seller and price are uncontrolled).
- **Impact:** late orders are only about 6.7% of volume but generate most of the 1 and 2 star reviews dragging the platform rating.
- **Recommendation:** optimise for hitting the promised date, not raw speed. Most orders already arrive early, so the focus is the small share of late orders: realistic estimates and flagging shipments likely to be late, especially long-distance ones.

### 2. Lateness is driven by distance, not product or seller quality

- **Finding:** the drivers of lateness are structural and geographic.
- **Evidence:** late rate climbs with customer-to-seller distance, from 4.5% under 100km to 10.3% beyond 1000km. It spikes occasionally (12.4% in November 2017 around Black Friday, and an unusual 19.0% in March 2018). Weight matters only for the 10kg+ tail. Category is negligible (6.3% to 8.0% across all). Sellers are spread, not concentrated: of 881 sellers with 20 or more delivered items, only 11 are chronically late.
- **Impact and recommendation:** the most effective fix is shortening long routes (fulfilling from the nearest seller), then adding capacity and widening estimates around known peaks. Coaching the roughly 166 sellers in the 10 to 25% late band is worthwhile; removing sellers in bulk is not, because the always-late group is tiny.

### 3. Revenue concentrates on sellers, not categories

- **Finding:** revenue risk is a supply-side (seller) story, not a demand-side (category) one.
- **Evidence:** the top 10% of sellers (310 of 3,095) drive 67.6% of GMV, the top 20% reach 82.7%, and the bottom half of sellers contribute about 2% combined. Revenue is spread across categories: no single category exceeds 9.3% of revenue, the top 5 are about 40%, and it takes roughly 20 of the 72 categories to reach 80%.
- **Recommendation:** treat the top few hundred sellers as key accounts, since retention there protects two-thirds of GMV. Category strategy can stay broad because no single category dominates. Seller quality does not vary with size, so there is no reason to limit larger sellers.

### 4. Customer value is concentrated, but the base is one-time buyers

- **Finding:** RFM segments concentrate value, but the dataset is dominated by single purchases.
- **Evidence:** about 97% of customers order exactly once, so the Frequency dimension carries little signal and Recency and Monetary do the work (Frequency is tiered with `CASE`, not `NTILE`, for that reason). Champions are 16.4% of customers but 30.2% of revenue; At-Risk are 15.5% of customers but 29.2% of revenue.
- **Recommendation:** the segments are descriptive value tiers, useful for prioritising marketing spend, not a live retention funnel. The At-Risk revenue figure is limited because most one-time buyers will not return.

### 5. Data quality: payment reconciliation

- **Finding:** 387 orders (about 0.4%) have a payment total that does not equal item price plus freight.
- **Evidence:** 294 are overpaid (average +R$10.44, consistent with installment interest) and 93 are underpaid (average -R$2.15, consistent with vouchers and discounts).
- **Handling:** captured by a singular test at WARN severity. These are real payment mechanics, so the right behaviour is to surface and explain them, not to fail the build.

## Scope and deliberate exclusions

Two things were deliberately not built, and the reasoning is part of the work:

- **No churn, lifetime-value, or retention model.** A roughly 3% repeat rate cannot support a reliable churn or CLV model: with about 97% of customers having a single order, there is no repeat-behaviour signal to learn from. RFM here is descriptive segmentation, not a retention funnel.
- **No profit or margin.** With no cost of goods in the source, any margin figure would be invented. All revenue is gross merchandise value, stated as such.

## How to run

The warehouse is DuckDB, so the whole project builds locally with no cloud account.

```bash
# 1. Olist CSVs into /data (gitignored), Kaggle slug olistbr/brazilian-ecommerce
# 2. install dependencies
uv sync
uv run dbt deps
# 3. build and test
uv run dbt build
# 4. generate the docs site and lineage graph
uv run dbt docs generate
```

`olist.duckdb` and `/data` are gitignored, so a clone needs the CSVs in place before the first build.

## What I would add for a team

This is a static, single-author project, so it does not include production monitoring. On a team it would also have: `sqlfluff` and pre-commit hooks for style and lint on every commit, `dbt-checkpoint` and `dbt-project-evaluator` to enforce documentation and best-practice coverage, a CI workflow running `dbt build` and lint on pull requests, model `contracts` on the public marts, and Elementary plus alerting for production runs. Each of these is worth adding once more than one person depends on the project; on a solo project like this they would be overkill.
