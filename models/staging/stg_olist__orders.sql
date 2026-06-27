with
    source as (select * from {{ source('olist', 'orders') }}),
    renamed as (
        select
            order_id,
            customer_id,
            order_status,
            order_purchase_timestamp,
            order_approved_at as order_approved_timestamp,
            order_delivered_carrier_date as order_delivered_carrier_timestamp,
            order_delivered_customer_date as order_delivered_customer_timestamp,
            cast(order_estimated_delivery_date as date) as order_estimated_delivery_date
        from source
    )
select *
from renamed
