-- BigQuery table name: dim_complaint_status
{{ config(alias='dim_complaint_status') }}

-- One row per unique complaint status (staging column is called status)
WITH statuses AS (
    SELECT DISTINCT status AS complaint_status
    FROM {{ ref('stg_nyc311_complaint') }}
)

-- Surrogate key for each status
SELECT
    {{ dbt_utils.generate_surrogate_key(['complaint_status']) }} AS complaint_status_key,
    complaint_status
FROM statuses

UNION ALL

-- Placeholder row for unknown values
SELECT '-1', CAST(NULL AS STRING)