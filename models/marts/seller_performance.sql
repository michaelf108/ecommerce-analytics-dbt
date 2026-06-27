-- Seller performance mart: one row per seller.
-- Revenue and freight are summed from line-grain items (additive).
-- Review score and late rate are order-grain attributes joined onto the items, so
-- they are item-weighted here (each item carries its order's value).
with
    order_items as (
        select
            order_id,
            seller_key,
            product_key,
            price,
            freight_value,
            customer_seller_distance_km
        from {{ ref('fct_order_items') }}
    ),
    orders as (
        select order_id, delivery_vs_estimate_days, avg_review_score
        from {{ ref('fct_orders') }}
    ),
    sellers as (
        select seller_key, seller_id, seller_state from {{ ref('dim_sellers') }}
    ),
    final as (
        select
            sellers.seller_key,
            sellers.seller_id,
            sellers.seller_state,
            count(*) as item_count,
            count(orders.delivery_vs_estimate_days) as delivered_item_count,
            count(distinct order_items.order_id) as order_count,
            count(distinct order_items.product_key) as product_count,
            round(sum(order_items.price), 2) as total_revenue,
            round(sum(order_items.freight_value), 2) as total_freight,
            round(avg(orders.avg_review_score), 2) as avg_review_score,
            round(
                count(*) filter (where orders.delivery_vs_estimate_days > 0)
                / nullif(count(orders.delivery_vs_estimate_days), 0),
                4
            ) as late_rate,
            round(avg(order_items.customer_seller_distance_km), 1) as avg_distance_km
        from order_items
        left join orders on order_items.order_id = orders.order_id
        left join sellers on order_items.seller_key = sellers.seller_key
        group by sellers.seller_key, sellers.seller_id, sellers.seller_state
    )
select *
from final
