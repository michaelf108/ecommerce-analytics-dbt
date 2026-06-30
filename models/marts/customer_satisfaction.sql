-- Customer satisfaction mart: one row per real customer (customer_unique_id).
-- Co-locates spend and review score at customer grain so high-value, low-review
-- customers can be found in one place (the star schema keeps these on separate
-- tables at different grains). Built like customer_rfm: orders are joined to the
-- real customer via dim_customers, then aggregated.
with
    orders as (
        select
            c.customer_unique_id,
            c.customer_state,
            c.customer_city,
            o.order_id,
            o.order_purchase_timestamp,
            o.total_payment_value,
            o.avg_review_score
        from {{ ref('fct_orders') }} o
        join {{ ref('dim_customers') }} c on o.customer_key = c.customer_key
    ),
    customer_agg as (
        select
            customer_unique_id,
            -- a person can have orders from more than one city; max() picks one
            max(customer_state) as customer_state,
            max(customer_city) as customer_city,
            count(distinct order_id) as order_count,
            round(sum(total_payment_value), 2) as total_spent,
            round(avg(avg_review_score), 2) as avg_review_score,
            -- most recent order's year and month (their only order for ~97%)
            year(max(order_purchase_timestamp)) as order_year,
            monthname(max(order_purchase_timestamp)) as order_month
        from orders
        group by customer_unique_id
    ),
    final as (
        select
            customer_unique_id,
            customer_state,
            customer_city,
            order_count,
            total_spent,
            avg_review_score,
            -- 0 = lowest spender, 1 = top spender
            round(percent_rank() over (order by total_spent), 4) as spending_percentile,
            order_year,
            order_month
        from customer_agg
    )
select *
from final
