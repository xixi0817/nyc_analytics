-- BigQuery table name: dim_complaint_type
{{ config(alias='dim_complaint_type') }}

-- One row per unique complaint type / descriptor combination
WITH types AS (
    SELECT DISTINCT complaint_type, descriptor
    FROM {{ ref('stg_nyc311_complaint') }}
)

-- Surrogate key for each combination
SELECT
    {{ dbt_utils.generate_surrogate_key(['complaint_type', 'descriptor']) }} AS complaint_type_key,
    complaint_type,
    descriptor
FROM types

UNION ALL

-- Placeholder row for unknown values
SELECT '-1', CAST(NULL AS STRING), CAST(NULL AS STRING)