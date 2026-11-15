-- BigQuery table name: dim_permit_type
{{ config(alias='dim_permit_type') }}

-- One row per unique job type / permit type / permit subtype combination
WITH types AS (
    SELECT DISTINCT job_type, permit_type, permit_subtype
    FROM {{ ref('stg_dob_permit') }}
)

-- Surrogate key for each combination
SELECT
    {{ dbt_utils.generate_surrogate_key(['job_type', 'permit_type', 'permit_subtype']) }} AS permit_type_key,
    job_type,
    permit_type,
    permit_subtype
FROM types

UNION ALL

-- Placeholder row for unknown values
SELECT '-1', CAST(NULL AS STRING), CAST(NULL AS STRING), CAST(NULL AS STRING)