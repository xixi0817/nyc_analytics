-- BigQuery table name: dim_owner_type
{{ config(alias='dim_owner_type') }}

-- One row per unique owner business type / non profit flag combination
WITH owners AS (
    SELECT DISTINCT owner_business_type, non_profit
    FROM {{ ref('stg_dob_permit') }}
)

-- Surrogate key for each combination
SELECT
    {{ dbt_utils.generate_surrogate_key(['owner_business_type', 'non_profit']) }} AS owner_type_key,
    owner_business_type,
    non_profit
FROM owners

UNION ALL

-- Placeholder row for unknown values
SELECT '-1', CAST(NULL AS STRING), CAST(NULL AS BOOL)