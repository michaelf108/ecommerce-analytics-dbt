with
    products as (select * from {{ ref('stg_olist__products') }}),
    categories as (select * from {{ ref('stg_olist__product_category_translation') }}),
    final as (
        select
            {{ dbt_utils.generate_surrogate_key(['product_id']) }} as product_key,
            products.product_id,
            products.product_category_name,
            categories.product_category_name_english,
            products.product_name_length,
            products.product_description_length,
            products.product_photos_qty,
            products.product_weight_g,
            products.product_length_cm,
            products.product_height_cm,
            products.product_width_cm
        from products
        left join
            categories
            on products.product_category_name = categories.product_category_name
    )
select *
from final
