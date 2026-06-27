/*
  FINDING: Late deliveries are strongly associated with lower review scores - a roughly
  2.5-star drop once an order misses its promised delivery date.

  EVIDENCE: Score falls 4.3 -> 1.7 with lateness, and the effect persists WITHIN product categories,
  weight bands, and distance bands. Distance has a minor own-effect (roughly 0.1 stars); lateness
  is roughly 20x larger and survives every control.

  IMPACT: Late orders (roughly 6.7% of volume) generate the 1-2 star reviews that drag the platform rating.

  RECOMMEND: Optimise for hitting the PROMISED date, not raw speed. The lever is the late tail:
  realistic estimates + flagging at-risk (esp. long-distance) shipments.

  CAVEAT: Association, not proof of causation. Controlled for category, weight, distance; seller/price remain.
*/
-- 1. Review score by delivery-vs-promise bucket
select
    case
        when delivery_vs_estimate_days < 0
        then '1 early'
        when delivery_vs_estimate_days = 0
        then '2 on time'
        when delivery_vs_estimate_days <= 5
        then '3 1-5 late'
        when delivery_vs_estimate_days <= 15
        then '4 6-15 late'
        else '5 15+ late'
    end as delivery_bucket,
    count(*) as orders,
    round(avg(avg_review_score), 2) as avg_score
from {{ ref('fct_orders') }}
where avg_review_score is not null and delivery_vs_estimate_days is not null
group by 1
order by 1
;

-- 2. Control for product category
select
    p.product_category_name_english as category,
    case
        when o.delivery_vs_estimate_days <= 0
        then '1 on-time/early'
        when o.delivery_vs_estimate_days <= 5
        then '2 1-5 late'
        else '3 6+ late'
    end as bucket,
    count(*) as items,
    round(avg(o.avg_review_score), 2) as avg_score
from {{ ref('fct_order_items') }} oi
join {{ ref('dim_products') }} p on oi.product_key = p.product_key
join {{ ref('fct_orders') }} o on oi.order_id = o.order_id
where
    o.avg_review_score is not null
    and o.delivery_vs_estimate_days is not null
    and p.product_category_name_english
    in ('bed_bath_table', 'health_beauty', 'sports_leisure', 'computers_accessories')
group by 1, 2
order by 1, 2
;

-- 3. Control for product weight
select
    case
        when p.product_weight_g < 500
        then '1 <500g'
        when p.product_weight_g < 2000
        then '2 0.5-2kg'
        else '3 2kg+'
    end as weight_band,
    case
        when o.delivery_vs_estimate_days <= 0
        then '1 on-time/early'
        when o.delivery_vs_estimate_days <= 5
        then '2 1-5 late'
        else '3 6+ late'
    end as bucket,
    count(*) as items,
    round(avg(o.avg_review_score), 2) as avg_score
from {{ ref('fct_order_items') }} oi
join {{ ref('dim_products') }} p on oi.product_key = p.product_key
join {{ ref('fct_orders') }} o on oi.order_id = o.order_id
where
    o.avg_review_score is not null
    and o.delivery_vs_estimate_days is not null
    and p.product_weight_g is not null
group by 1, 2
order by 1, 2
;

-- 4. Control for customer to seller distance (fact measure)
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
    case
        when fo.delivery_vs_estimate_days <= 0
        then '1 on-time/early'
        when fo.delivery_vs_estimate_days <= 5
        then '2 1-5 late'
        else '3 6+ late'
    end as bucket,
    count(*) as items,
    round(avg(fo.avg_review_score), 2) as avg_score
from {{ ref('fct_order_items') }} oi
join {{ ref('fct_orders') }} fo on oi.order_id = fo.order_id
where
    fo.avg_review_score is not null
    and fo.delivery_vs_estimate_days is not null
    and oi.customer_seller_distance_km is not null
group by 1, 2
order by 1, 2
;
