-- BigQuery table name: dim_permit_status
{{ config(alias='dim_permit_status') }}

-- One row per unique filing status / permit status combination
WITH statuses AS (
    SELECT DISTINCT filing_status, permit_status
    FROM {{ ref('stg_dob_permit') }}
)

-- Surrogate key for each combination
SELECT
    {{ dbt_utils.generate_surrogate_key(['filing_status', 'permit_status']) }} AS permit_status_key,
    filing_status,
    permit_status
FROM statuses

UNION ALL

-- Placeholder row for unknown values
SELECT '-1', CAST(NULL AS STRING), CAST(NULL AS STRING)