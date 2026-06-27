with
    orders as (
        -- one row per order, with the REAL customer (unique_id) + the fields needed
        select c.customer_unique_id, o.order_purchase_timestamp, o.total_payment_value
        from {{ ref('fct_orders') }} o
        join {{ ref('dim_customers') }} c on o.customer_key = c.customer_key
        where o.total_payment_value is not null  -- ignore orders with no payment
    ),
    rfm_base as (
        select
            customer_unique_id,
            date_diff(
                'day',
                max(order_purchase_timestamp),
                (select max(order_purchase_timestamp) from orders)
            ) as recency_days,
            count(*) as frequency,
            round(sum(total_payment_value), 2) as monetary
        from orders
        group by customer_unique_id
    ),
    rfm_scored as (
        select
            customer_unique_id,
            recency_days,
            frequency,
            monetary,
            ntile(5) over (order by recency_days desc) as r_score,
            ntile(5) over (order by monetary) as m_score,
            case
                when frequency = 1 then 1 when frequency = 2 then 3 else 5
            end as f_score
        from rfm_base
    ),
    rfm_segments as (
        select
            *,
            case
                when f_score = 5
                then 'Loyal (3+ orders)'  -- rare repeat buyers
                when r_score >= 4 and m_score >= 4
                then 'Champions'  -- recent + high value
                when m_score >= 4 and r_score <= 2
                then 'At Risk'  -- high value, going quiet
                when r_score >= 4 and m_score <= 2
                then 'New / Low-Value'  -- recent but low spend
                when r_score <= 2 and m_score <= 2
                then 'Lost'  -- gone + low value
                else 'Regular'
            end as segment
        from rfm_scored
    )
select *
from rfm_segments
