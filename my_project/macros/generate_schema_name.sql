-- generate_schema_name.sql
-- provides a macro to override the default generate_schema_name macro
-- (see https://docs.getdbt.com/docs/build/custom-schemas#advanced-custom-schema-configuration for details)

{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set env_name = target.name -%}

    {%- if env_name == 'prod' %}

        dbt_{{ custom_schema_name }}

    {%- else -%}

        dbt_{{ custom_schema_name | trim }}_{{ env_name }}

    {%- endif -%}

{%- endmacro %}
