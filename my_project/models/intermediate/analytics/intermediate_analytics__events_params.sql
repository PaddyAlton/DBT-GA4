-- intermediate_analytics__events_params.sql
-- 1st stage intermediate model: unwraps parameters into separate rows
-- (one row per event/parameter pair, or per event for events without parameters)
-- Configured to build an incrementally-materialised table

{{
  config(
    materialized = 'incremental',
    partition_by = {
      'field': 'event_date', 
      'data_type': 'date', 
      'granularity': 'day'},
    incremental_strategy = 'insert_overwrite',
    unique_key = 'param_id',
    on_schema_change = 'fail',
    tags=['incremental', 'daily']
  )
}}

    SELECT
        -- surrogate key (unique for each event/param pair):
        {{ dbt_utils.generate_surrogate_key(['event_id', 'params.key']) }} AS param_id,
        -- event data:
        event_id,
        event_date,
        event_timestamp,
        client_id,
        user_id,
        event_name,
        -- fields extracted from various struct fields:
        geo.continent AS continent,
        geo.country AS country,
        device.category AS device_type,
        device.web_info.browser AS browser,
        device.operating_system AS operating_system,
        traffic_source.source AS traffic_source,
        traffic_source.name AS traffic_campaign,
        traffic_source.medium AS traffic_medium,
        -- cross-joined parameter key/value pairs:
        params.key AS param_key,
        COALESCE(
          params.value.string_value,
          CAST(params.value.int_value AS STRING),
          CAST(params.value.float_value AS STRING),
          CAST(params.value.double_value AS STRING)
        ) AS param_value,
      FROM ( -- subquery allows us to efficiently build this table incrementally
               SELECT *
                 FROM
                   {{ ref('base_analytics__events') }}
{% if is_incremental() %}
                WHERE -- in incremental mode, add/replace data from last daily partition onwards:
                      event_date >= DATE(_dbt_max_partition)
                      -- also add/replace data originally generated
                      -- today, yesterday, or the day-before-yesterday
                      -- (events_intraday data can be mutated on transfer to events)
                   OR event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
{% endif %}
           )
 LEFT JOIN
        -- unwrap the event parameters: every event/parameter pair is a record
        -- (plus any events without parameters, hence LEFT JOIN)
        UNNEST(event_params) AS params
