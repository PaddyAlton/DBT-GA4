-- tests/generic/array_not_empty.sql
-- defines a generic test to check that arrays are not missing
-- and do not have length zero

{% test array_not_empty(model, column_name) %}

WITH validation_query AS (
    SELECT
        {{ column_name }} AS arraylike_field
      FROM
        {{ model }}
),
validation_errors AS (
    SELECT
        arraylike_field
      FROM
        validation_query
     WHERE
           ARRAY_LENGTH(arraylike_field) = 0
        OR arraylike_field IS NULL
)

-- if this returns any records, the test fails
-- (it means there are values that have zero length or are NULL)
SELECT * FROM validation_errors

{% endtest %}
