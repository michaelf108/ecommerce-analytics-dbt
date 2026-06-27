with
    order_items as (select * from {{ ref('stg_olist__order_items') }}),
    products as (select product_key, product_id from {{ ref('dim_products') }}),
    sellers as (
        select seller_key, seller_id, seller_zip_code_prefix
        from {{ ref('dim_sellers') }}
    ),
    orders as (select order_id, customer_id from {{ ref('stg_olist__orders') }}),
    customers as (
        select customer_id, customer_zip_code_prefix from {{ ref('dim_customers') }}
    ),
    geo as (
        select zip_code_prefix, latitude, longitude
        from {{ ref('int_geolocation_deduped') }}
    ),
    final as (
        select
            {{ dbt_utils.generate_surrogate_key(['order_items.order_id', 'order_items.order_item_id']) }}
            as order_item_key,
            order_items.order_id,
            order_items.order_item_id,
            products.product_key,
            sellers.seller_key,
            order_items.shipping_limit_timestamp,
            order_items.price,
            order_items.freight_value,
            2
            * 6371
            * asin(
                sqrt(
                    pow(sin(radians(sgeo.latitude - cgeo.latitude) / 2), 2)
                    + cos(radians(cgeo.latitude))
                    * cos(radians(sgeo.latitude))
                    * pow(sin(radians(sgeo.longitude - cgeo.longitude) / 2), 2)
                )
            ) as customer_seller_distance_km
        from order_items
        left join products on order_items.product_id = products.product_id
        left join sellers on order_items.seller_id = sellers.seller_id
        left join orders on order_items.order_id = orders.order_id
        left join customers on orders.customer_id = customers.customer_id
        left join
            geo as cgeo on customers.customer_zip_code_prefix = cgeo.zip_code_prefix
        left join geo as sgeo on sellers.seller_zip_code_prefix = sgeo.zip_code_prefix
    )
select *
from final
