-- Category satisfaction mart: review-score distribution per product category,
-- one row per (product_category, review_score).
-- Review score lives at order grain and category at product grain, so the star
-- schema can't cross them directly. Each order's review is attached to its line
-- items (item-weighted, like seller_performance), then counted per category and
-- whole-star score - the shape a 100% stacked bar needs.
with
    items as (select order_id, product_key from {{ ref('fct_order_items') }}),
    orders as (select order_id, avg_review_score from {{ ref('fct_orders') }}),
    products as (
        select
            product_key,
            coalesce(
                product_category_name_english,
                product_category_name,
                '(uncategorised)'
            ) as product_category
        from {{ ref('dim_products') }}
    ),
    item_reviews as (
        select
            p.product_category,
            cast(round(o.avg_review_score) as integer) as review_score
        from items i
        join orders o on i.order_id = o.order_id
        join products p on i.product_key = p.product_key
        where o.avg_review_score is not null
    ),
    final as (
        select product_category, review_score, count(*) as item_count
        from item_reviews
        group by product_category, review_score
    )
select *
from final
