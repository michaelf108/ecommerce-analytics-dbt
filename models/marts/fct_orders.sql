with
    orders as (select * from {{ ref('stg_olist__orders') }}),
    customers as (select customer_key, customer_id from {{ ref('dim_customers') }}),
    items as (select * from {{ ref('int_order_items_aggregated') }}),
    payments as (select * from {{ ref('int_order_payments_aggregated') }}),
    reviews as (select * from {{ ref('int_order_reviews_aggregated') }}),
    final as (
        select
            {{ dbt_utils.generate_surrogate_key(['orders.order_id']) }} as order_key,
            orders.order_id,
            customers.customer_key,
            orders.order_status,
            orders.order_purchase_timestamp,
            orders.order_approved_timestamp,
            orders.order_delivered_carrier_timestamp,
            orders.order_delivered_customer_timestamp,
            orders.order_estimated_delivery_date,
            items.item_count,
            items.total_item_price,
            items.total_freight_value,
            payments.total_payment_value,
            payments.payment_count,
            reviews.avg_review_score,
            reviews.review_count,
            date_diff(
                'day',
                orders.order_purchase_timestamp,
                orders.order_delivered_customer_timestamp
            ) as delivery_days,
            date_diff(
                'day',
                orders.order_estimated_delivery_date,
                orders.order_delivered_customer_timestamp
            ) as delivery_vs_estimate_days
        from orders
        left join customers on orders.customer_id = customers.customer_id
        left join items on orders.order_id = items.order_id
        left join payments on orders.order_id = payments.order_id
        left join reviews on orders.order_id = reviews.order_id
    )
select *
from final
