/*
  Context: where does Olist's revenue concentrate - on the supply side (sellers) or the demand side
  (product categories)? That tells you where the platform's revenue risk and growth levers sit.

  FINDING: the concentration is on the SELLER side, not the category side.
    - SELLERS (steep Pareto): the top 10% of sellers (310 of 3,095) drive ~68% of GMV, the top 20%
      ~83%, the top 30% ~90%. The bottom half of sellers contribute ~2% combined.
    - CATEGORIES (spread out): no single category exceeds ~9% (health_beauty 9.3%, watches_gifts 8.9%,
      bed_bath_table 7.6%). The top 5 are ~40%, and it takes ~20 of the ~72 categories to reach 80%.

  SO WHAT: revenue risk is a seller-dependency story, not a category one. Demand is broad-based across
  product lines; supply leans heavily on a small set of sellers.

  RECOMMEND:
    1. Treat the top ~300 sellers (top decile) as key accounts - retention there protects roughly
       two-thirds of GMV, and losing a handful is a material revenue risk.
    2. Don't over-index strategy on one or two categories - none dominates, so merchandising and
       growth can stay broad.
    3. Moving mid-tier sellers up the curve is a more direct GMV lever than chasing any single category.

  CAVEAT: revenue = item price (line grain, additive); GMV here excludes freight. Category from
  dim_products (English translation; missing categories grouped as '(uncategorised)'). The seller
  curve reuses the seller_performance mart.
*/
-- 1. Revenue by product category (top 15) - spread out: no category over ~9%, ~20
-- categories to reach 80%
with
    category_rev as (
        select
            coalesce(p.product_category_name_english, '(uncategorised)') as category,
            sum(oi.price) as revenue
        from {{ ref('fct_order_items') }} oi
        join {{ ref('dim_products') }} p on oi.product_key = p.product_key
        group by 1
    ),
    ranked as (
        select
            category,
            revenue,
            row_number() over (order by revenue desc) as category_rank,
            sum(revenue) over () as total_rev,
            sum(revenue) over (
                order by revenue desc rows unbounded preceding
            ) as cum_rev
        from category_rev
    )
select
    category_rank,
    category,
    round(revenue) as revenue,
    round(100.0 * revenue / total_rev, 1) as pct_revenue,
    round(100.0 * cum_rev / total_rev, 1) as cum_pct_revenue
from ranked
order by category_rank
limit 15
;

-- 2. Revenue by seller decile (reuses seller_performance) - steep: top decile = ~68%
-- of GMV
with
    ranked as (
        select total_revenue, ntile(10) over (order by total_revenue desc) as decile
        from {{ ref('seller_performance') }}
    ),
    by_decile as (
        select decile, count(*) as sellers, sum(total_revenue) as revenue
        from ranked
        group by decile
    )
select
    decile,
    sellers,
    round(revenue) as revenue,
    round(100.0 * revenue / sum(revenue) over (), 1) as pct_revenue,
    round(
        100.0 * sum(revenue) over (order by decile) / sum(revenue) over (), 1
    ) as cum_pct_revenue
from by_decile
order by decile
;
