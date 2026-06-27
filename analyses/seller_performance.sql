/*
  Context: seller_performance mart (one row per seller). Where revenue concentrates, and whether
  bigger sellers deliver any better, are both useful for where a marketplace puts its attention.

  FINDING:
    - Revenue is highly concentrated. The top 1% of sellers (30 of 3,095) drive ~26% of GMV, the
      top 5% (~154 sellers) ~53%, and the top 20% ~83% - a textbook Pareto curve.
    - Scale does NOT predict quality. Average review (~3.9-4.1) and late rate (~6.5-7.1%) are
      essentially flat across volume bands. The smallest sellers (<10 items) are marginally worse
      (3.90 review, 7.1% late), but the gap is minor; large sellers are no better or worse than
      mid-sized ones.
    - Lateness is SPREAD, not concentrated (confirms drivers_of_lateness, now at seller grain). Of
      881 sellers with >=20 delivered items, the bulk of volume sits in the 5-10% late band; only 11
      sellers are chronically late (25%+) and they ship just 423 items. Not a few-bad-apples problem.

  RECOMMEND:
    1. Protect and grow the top ~150 sellers (top 5%) - over half of GMV runs through them, which is
       also a concentration/dependency risk worth monitoring.
    2. Don't gate or cull on size - large sellers aren't a quality risk, and the chronically-late tail
       is too small to move the platform's late rate. Lateness is a logistics problem (distance, see
       drivers_of_lateness), not a seller-quality one.
    3. Coach the ~166 sellers in the 10-25% late band (real volume, fixable) ahead of the 11 worst
       (negligible volume).

  CAVEAT: review score and late rate are item-weighted at the seller grain (each item carries its
  order's value); late rate is over delivered items only.
*/
-- 1. Revenue concentration - bands are mutually-exclusive slices; cumulative top 20%
-- = bands 1-4 (~83%)
with
    ranked as (
        select
            total_revenue,
            row_number() over (order by total_revenue desc) as seller_rank,
            count(*) over () as n_sellers,
            sum(total_revenue) over () as total_rev
        from {{ ref('seller_performance') }}
    )
select
    case
        when seller_rank <= 0.01 * n_sellers
        then '1 top 1%'
        when seller_rank <= 0.05 * n_sellers
        then '2 top 5%'
        when seller_rank <= 0.10 * n_sellers
        then '3 top 10%'
        when seller_rank <= 0.20 * n_sellers
        then '4 top 20%'
        else '5 rest'
    end as seller_band,
    count(*) as sellers,
    round(sum(total_revenue)) as revenue,
    round(100.0 * sum(total_revenue) / max(total_rev), 1) as pct_revenue
from ranked
group by 1
order by 1
;

-- 2. Quality vs volume - does seller scale predict review score or late rate?
-- (seller-weighted)
select
    case
        when item_count < 10
        then '1 <10 items'
        when item_count < 50
        then '2 10-50'
        when item_count < 200
        then '3 50-200'
        else '4 200+'
    end as volume_band,
    count(*) as sellers,
    sum(item_count) as items,
    round(avg(avg_review_score), 2) as avg_review,
    round(100.0 * avg(late_rate), 1) as avg_late_pct
from {{ ref('seller_performance') }}
group by 1
order by 1
;

-- 3. Late-rate distribution across sellers (>=20 delivered items) - spread, not a few
-- bad apples
select
    case
        when late_rate = 0
        then '1 never late'
        when late_rate < 0.05
        then '2 <5%'
        when late_rate < 0.10
        then '3 5-10%'
        when late_rate < 0.25
        then '4 10-25%'
        else '5 25%+'
    end as seller_late_band,
    count(*) as sellers,
    sum(delivered_item_count) as items
from {{ ref('seller_performance') }}
where late_rate is not null and delivered_item_count >= 20
group by 1
order by 1
;
