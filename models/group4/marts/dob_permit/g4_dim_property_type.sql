-- BigQuery table name: dim_property_type
{{ config(alias='dim_property_type') }}

-- One row per unique building type / residential flag combination
WITH props AS (
    SELECT DISTINCT bldg_type, residential
    FROM {{ ref('stg_dob_permit') }}
)

-- Surrogate key for each combination
SELECT
    {{ dbt_utils.generate_surrogate_key(['bldg_type', 'residential']) }} AS property_type_key,
    bldg_type,
    residential
FROM props

UNION ALL

-- Placeholder row for unknown values
SELECT '-1', CAST(NULL AS STRING), CAST(NULL AS BOOL)