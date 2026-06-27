with
    geolocation as (select * from {{ ref('stg_olist__geolocation') }}),
    deduped as (
        select
            geolocation_zip_code_prefix as zip_code_prefix,
            avg(geolocation_lat) as latitude,
            avg(geolocation_lng) as longitude
        from geolocation
        group by geolocation_zip_code_prefix
    )
select *
from deduped
