/*
  FINDING: Revenue is concentrated. Champions + At-Risk = ~32% of customers but roughly 60% of revenue. At-Risk alone = 15.5% of
  customers / 29.2% of revenue (about R$4.67M) - high past value, now lapsing.

  METHOD: RFM at customer_unique_id grain (the real person). R & M scored via NTILE(5) quintiles; F tiered by CASE (NOT NTILE)
  because roughly 97% of customers are one-time buyers - NTILE on a 97%-tied column is meaningless. Segments are therefore R+M-led.

  SCOPE & DELIBERATE EXCLUSIONS: Predictive churn / CLV / retention modelling was deliberately NOT built. A roughly 3% repeat rate
  cannot support a reliable churn or lifetime-value model - ~97% of customers have exactly one order, so there is no repeat-behaviour
  signal to learn from. These segments are DESCRIPTIVE value tiers, not a live retention funnel; 'winning back' At-Risk revenue is structurally bounded.
*/
-- 1. Frequency distribution - evidence that F is degenerate (~97% one-time)
select
    frequency,
    count(*) as customers,
    round(100.0 * count(*) / sum(count(*)) over (), 1) as pct
from {{ ref('customer_rfm') }}
group by frequency
order by frequency
;

-- 2. Segment sizes
select
    segment,
    count(*) as customers,
    round(100.0 * count(*) / sum(count(*)) over (), 1) as pct_customers
from {{ ref('customer_rfm') }}
group by segment
order by customers desc
;

-- 3. Revenue concentration - the headline (% customers vs % revenue)
select
    segment,
    count(*) as customers,
    round(100.0 * count(*) / sum(count(*)) over (), 1) as pct_customers,
    round(sum(monetary)) as revenue,
    round(100.0 * sum(monetary) / sum(sum(monetary)) over (), 1) as pct_revenue
from {{ ref('customer_rfm') }}
group by segment
order by revenue desc
;
