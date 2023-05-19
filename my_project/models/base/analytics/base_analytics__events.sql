-- base_analytics__events.sql
-- base model for GA4 data exported to BigQuery
-- configured to build an incrementally-materialised table
-- See GA4 Export Schema: https://support.google.com/analytics/answer/7029846?hl=en

{{
  config(
    materialized = 'incremental',
    partition_by = {
      'field': 'event_date', 
      'data_type': 'date', 
      'granularity': 'day'},
    incremental_strategy = 'insert_overwrite',
    unique_key='event_id',
    on_schema_change = 'fail',
    tags=['incremental', 'daily']
  )
}}

    SELECT
     -- generate surrogate 'event' ID
        {{ dbt_utils.generate_surrogate_key([
           'event_timestamp',
           'event_name',
           'user_pseudo_id',
           'ARRAY_TO_STRING(ARRAY(SELECT CONCAT(p.key, "::", COALESCE(p.value.string_value, CAST(p.value.int_value AS STRING), CAST(p.value.float_value AS STRING), CAST(p.value.double_value AS STRING))) FROM UNNEST(event_params) AS p), "; ")'
        ]) }} AS event_id,
     -- partitioning key:
        PARSE_DATE('%Y%m%d', event_date) AS event_date, -- equivalent to _table_suffix; convert to DATE type
     -- other fields:
        TIMESTAMP_MICROS(event_timestamp) AS event_timestamp,
        event_name,
        event_params, -- Structure { key, value }
        event_previous_timestamp,
        event_value_in_usd,
        event_bundle_sequence_id,
        event_server_timestamp_offset,
        user_pseudo_id AS client_id,
        user_id,
        privacy_info, -- Structure { analytics_storage, ads_storage, users_transient_token }
        user_properties, -- Structure { key, value }
        user_first_touch_timestamp,
        user_ltv, -- Structure { revenue, currency }
        device, -- Structure containing many fields
        geo, -- Structure containing many fields
        app_info, -- Structure containing many fields
        traffic_source, -- Structure { name, medium, source}
        stream_id,
        platform,
        event_dimensions, -- Structure { hostname }
        ecommerce, -- Structure containing many fields
        items, -- Structure containing many fields
      FROM
        {{ source('google_analytics_live', 'events') }}
{% if is_incremental() %}
     WHERE
           -- events from the 'intraday' tables should always be included
           _table_suffix LIKE 'intraday_%'
        OR (
           -- add/replace data from last daily partition onwards, regardless:
              PARSE_DATE('%Y%m%d', _table_suffix) >= DATE(_dbt_max_partition)
           -- add/replace data originally generated
           -- today, yesterday, or the day-before-yesterday
           -- (events_intraday data can be mutated on transfer to events)
           OR PARSE_DATE('%Y%m%d', _table_suffix) >= DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
           )
{% endif %}
