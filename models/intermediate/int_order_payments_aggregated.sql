with
    order_payments as (select * from {{ ref('stg_olist__order_payments') }}),
    aggregated as (
        select
            order_id,
            sum(payment_value) as total_payment_value,
            count(*) as payment_count
        from order_payments
        group by order_id
    )
select *
from aggregated
