-- tests/generic/is_boolean.sql
-- defines a generic test to check that values are only Boolean/Null

{% test is_boolean(model, column_name) %}

WITH validation_query AS (
    SELECT
        {{ column_name }} AS boolean_field
      FROM
        {{ model }}
),
validation_errors AS (
    SELECT
        boolean_field
      FROM
        validation_query
     WHERE
        boolean_field NOT IN (true, false)
        -- NULL NOT IN (true, false) evaluates to **false**
        -- so test for null values separately if desired
)

-- if this returns any records, the test fails
-- (it means there are values that are neither TRUE nor FALSE nor NULL)
SELECT * FROM validation_errors

{% endtest %}
