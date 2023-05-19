-- marts_analytics__ga_events.sql
-- Incrementally materialised table containing records of Google Analytics events from GA4

{{
  config(
    materialized = 'incremental',
    partition_by = {
      'field': 'event_date',
      'data_type': 'date',
      'granularity': 'day'},
    incremental_strategy = 'insert_overwrite',
    unique_key = 'event_id',
    on_schema_change = 'fail',
    tags=['incremental', 'daily']
  )
}}

    SELECT
        event_id,
        event_date,
        event_timestamp,
        client_id,
        session_id,
        user_id,
        event_name,
        REGEXP_EXTRACT(
          page_location,
          r'(?:[a-zA-Z]+://)?(?:[a-zA-Z0-9-.]+){1}(/[^\?#;&]+)' -- any protocol, any host, capture /path
        ) AS page_path,
        REGEXP_EXTRACT(page_location, r'\?([^#]*)') AS query_params,
        REGEXP_EXTRACT(page_location, r'#(.*)') AS fragment,
        link_click_target,
      FROM
        {{ ref('intermediate_analytics__events_wide_format') }}
     WHERE -- ignore data before the union point with UA archival data:
           event_date >= {{ var('ua_ga4_stitch_date') }}
{% if is_incremental() %}
       AND ( -- in incremental mode, add/replace data from last daily partition onwards:
                event_date >= DATE(_dbt_max_partition)
             -- also add/replace data originally generated
             -- today, yesterday, or the day-before-yesterday
             -- (events_intraday data can be mutated on transfer to events)
             OR event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
           )
{% endif %}
