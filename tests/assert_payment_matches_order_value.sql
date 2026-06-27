{{ config(severity = 'warn') }}

-- Reconciliation monitor: an order's total payment should equal items + freight.
-- Olist orders legitimately diverge (vouchers, discounts, installment fees), so this
-- runs as WARN - it surfaces the count of mismatches without failing the build.
-- A singular test returns the FAILING rows: orders where payment <> items + freight
-- by >1 cent.
select
    order_id,
    total_payment_value,
    total_item_price + total_freight_value as expected_value,
    total_payment_value - (total_item_price + total_freight_value) as difference
from {{ ref('fct_orders') }}
where
    total_payment_value is not null
    and total_item_price is not null
    and total_freight_value is not null
    and abs(total_payment_value - (total_item_price + total_freight_value)) > 0.01
