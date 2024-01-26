-- intermediate_analytics__events_wide_format.sql
-- 2nd stage intermediate model: a wide-format (pivoted) table of events data
-- from Google Analytics (one row per event)
-- Configured to build an incrementally materialised table

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
        user_id,
        event_name,
        continent,
        country,
        device_type,
        browser,
        operating_system,
        -- rename various fields output by the pivot operation below:
        val_page_location AS page_location,
        val_page_referrer AS page_referrer,
        ---- note we append the client ID to the session ID to ensure
        ---- that the session ID will be globally unique:
        CONCAT(val_ga_session_id, '-', client_id) AS session_id,
        val_click_element_url AS link_click_target,
        -- referrer information:
        traffic_source,
        traffic_medium,
        traffic_campaign,
        REGEXP_EXTRACT(val_page_location, 'utm_content=([^&]+)') AS traffic_referrer,
      FROM ( -- Subquery allows WHERE + PIVOT in the same expression
               SELECT 
             DISTINCT -- ensure we get just one row per event in the pivot output
                   * EXCEPT(param_id)
                 FROM
                   {{ ref('intermediate_analytics__events_params') }}
{% if is_incremental() %}
                WHERE -- in incremental mode, add/replace data from last daily partition onwards:
                      event_date >= DATE(_dbt_max_partition)
                      -- also add/replace data originally generated
                      -- today, yesterday, or the day-before-yesterday
                      -- (events_intraday data can be mutated on transfer to events)
                   OR event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
{% endif %}
     )
     PIVOT(
        /*
        Pivoting typically requires aggregation of the returned values
        over their parent rows.
        Here we expect one value for each combination of param_key and
        other fields, so non-deterministically selecting ANY_VALUE is
        used to perform the 'aggregation'
        */
        ANY_VALUE(param_value) AS val
        FOR param_key IN (
        -- list of keys for which we want corresponding values (PICK YOUR OWN):
          'ga_session_id',
          'page_location',
          'page_referrer',
          'click_element_url'
        )
     )
