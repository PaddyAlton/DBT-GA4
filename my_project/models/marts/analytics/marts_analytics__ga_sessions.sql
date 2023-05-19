-- marts_analytics__ga_sessions.sql
-- Incrementally materialised table containing records of Google Analytics sessions from GA4

{{
  config(
    materialized = 'incremental',
    partition_by = {
      'field': 'session_date',
      'data_type': 'date',
      'granularity': 'day'},
    incremental_strategy = 'insert_overwrite',
    unique_key = 'session_id',
    on_schema_change = 'fail',
    tags=['incremental', 'daily']
  )
}}

    SELECT -- deduplicate session-scoped data ...
  DISTINCT -- window functions will produce multiple equivalent records
        session_id,
        client_id,
        -- apply window calculations
        LAST_VALUE(continent) OVER(session_window) AS continent,
        LAST_VALUE(country) OVER(session_window) AS country,
        LAST_VALUE(device_type) OVER(session_window) AS device_type,
        LAST_VALUE(browser) OVER(session_window) AS browser,
        LAST_VALUE(operating_system) OVER(session_window) AS operating_system,
        FIRST_VALUE(event_date) OVER(session_window) AS session_date,
        FIRST_VALUE(event_timestamp) OVER(session_window) AS session_initiated,
        FIRST_VALUE(page_location) OVER(session_window) AS landing_page, 
        LAST_VALUE(page_location) OVER(session_window) AS exit_page,
        FIRST_VALUE(traffic_source) OVER(session_window) AS traffic_source,
        FIRST_VALUE(traffic_campaign) OVER(session_window) AS traffic_campaign,
        FIRST_VALUE(traffic_medium) OVER(session_window) AS traffic_medium,
        FIRST_VALUE(traffic_referrer) OVER(session_window) AS traffic_referrer,
      FROM
        {{ ref('intermediate_analytics__events_wide_format') }}
{% if is_incremental() %}
   QUALIFY
        -- recalculate data for sessions commencing during/after the last previously-seen date:
           FIRST_VALUE(event_date) OVER(session_window) >= DATE(_dbt_max_partition)
           -- also add/replace data originally generated
           -- today, yesterday, or the day-before-yesterday
           -- (events_intraday data can be mutated on transfer to events)
        OR FIRST_VALUE(event_date) OVER(session_window) >= DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
{% endif %}
    WINDOW -- 
        session_window AS (
            PARTITION BY session_id
                ORDER BY event_timestamp
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        )    
