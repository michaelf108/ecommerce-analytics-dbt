/*
FINDING: Lateness is primarily a GEOGRAPHY/LOGISTICS problem, not a product- or seller-quality problem.
              - Distance: STRONG, structural - 4.5% (<100km) -> 10.3% (1000km+).
              - Seasonality: EPISODIC - 12.4% (Nov 2017, Black Friday) and an anomalous 14.1% -> 19.0% in Feb-Mar 2018 (root-cause TBC).
              - Weight: MINOR - flat until 10kg+ (9.3%).
              - Sellers: SPREAD, not concentrated - bulk of volume at 5-10% late; only 11 sellers at 25%+ (423 items).
              - Category: NEGLIGIBLE (6.3-8.0% across all).

RECOMMEND: 1. Fulfilment network / nearest-seller fulfilment to shorten long routes (distance = dominant lever).
            2. Pre-scale capacity + widen estimates for known peaks (Black Friday).
            3. Root-cause the Mar 2018 spike (19%) - one-off vs recurring?
            4. Coach the ~166 sellers in the 10-25% tail; don't mass-cull (catastrophic group too small).
            5. Special handling for 10kg+ items (minor).
            6. Skip category-specific handling (no signal).

CAVEAT: Line-item grain (multi-item orders counted per item); delivered orders only; distance = haversine between zip-prefix centroids.
*/
-- 1. Late rate by customer<->seller distance (fact measure) -- dominant driver
select
    case
        when oi.customer_seller_distance_km < 100
        then '1 <100km'
        when oi.customer_seller_distance_km < 500
        then '2 100-500km'
        when oi.customer_seller_distance_km < 1000
        then '3 500-1000km'
        else '4 1000km+'
    end as distance_band,
    count(*) as items,
    round(avg(oi.customer_seller_distance_km)) as avg_km,
    round(
        100.0 * avg(case when o.delivery_vs_estimate_days <= 0 then 0 else 1 end), 1
    ) as pct_late
from {{ ref('fct_order_items') }} oi
join {{ ref('fct_orders') }} o on oi.order_id = o.order_id
where
    o.delivery_vs_estimate_days is not null
    and oi.customer_seller_distance_km is not null
group by 1
order by 1
;

-- 2. Late rate by product weight -- minor, heavy tail only
select
    case
        when p.product_weight_g < 500
        then '1 <500g'
        when p.product_weight_g < 2000
        then '2 0.5-2kg'
        when p.product_weight_g < 10000
        then '3 2-10kg'
        else '4 10kg+'
    end as weight_band,
    count(*) as items,
    round(
        100.0 * avg(case when o.delivery_vs_estimate_days <= 0 then 0 else 1 end), 1
    ) as pct_late
from {{ ref('fct_order_items') }} oi
join {{ ref('dim_products') }} p on oi.product_key = p.product_key
join {{ ref('fct_orders') }} o on oi.order_id = o.order_id
where o.delivery_vs_estimate_days is not null and p.product_weight_g is not null
group by 1
order by 1
;

-- 3. Late rate by product category (>=1000 items) -- negligible signal
select
    p.product_category_name_english as category,
    count(*) as items,
    round(
        100.0 * avg(case when o.delivery_vs_estimate_days <= 0 then 0 else 1 end), 1
    ) as pct_late
from {{ ref('fct_order_items') }} oi
join {{ ref('dim_products') }} p on oi.product_key = p.product_key
join {{ ref('fct_orders') }} o on oi.order_id = o.order_id
where
    o.delivery_vs_estimate_days is not null
    and p.product_category_name_english is not null
group by 1
having count(*) >= 1000
order by pct_late desc
;

-- 4. Seller reliability distribution (sellers with >=20 items) -- spread, not
-- concentrated
with
    seller_stats as (
        select
            oi.seller_key,
            count(*) as items,
            avg(
                case when o.delivery_vs_estimate_days <= 0 then 0 else 1 end
            ) as late_rate
        from {{ ref('fct_order_items') }} oi
        join {{ ref('fct_orders') }} o on oi.order_id = o.order_id
        where o.delivery_vs_estimate_days is not null
        group by 1
        having count(*) >= 20
    )
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
    sum(items) as items
from seller_stats
group by 1
order by 1
;

-- 5. Late rate by order month -- seasonal/event spikes
select
    cast(date_trunc('month', o.order_purchase_timestamp) as date) as month,
    count(*) as orders,
    round(
        100.0 * avg(case when o.delivery_vs_estimate_days <= 0 then 0 else 1 end), 1
    ) as pct_late
from {{ ref('fct_orders') }} o
where o.delivery_vs_estimate_days is not null
group by 1
order by 1
;
