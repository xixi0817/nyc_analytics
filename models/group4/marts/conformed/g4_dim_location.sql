-- Use a clean table name in BigQuery (dim_location) while keeping a unique dbt model name
{{ config(alias='dim_location') }}

-- Collect every borough + zip combination from both staging tables
WITH all_locations AS (
    SELECT DISTINCT borough, zip_code FROM {{ ref('stg_dob_permit') }}
    UNION DISTINCT
    SELECT DISTINCT borough, zip_code FROM {{ ref('stg_nyc311_complaint') }}
),

-- Drop rows with no borough
cleaned AS (
    SELECT * FROM all_locations
    WHERE borough IS NOT NULL
)

-- Build a surrogate key for each location
SELECT
    {{ dbt_utils.generate_surrogate_key(['borough', 'zip_code']) }} AS location_key,
    borough,
    zip_code
FROM cleaned

UNION ALL

-- Placeholder row for facts with an unknown location
SELECT '-1' AS location_key, CAST(NULL AS STRING) AS borough, CAST(NULL AS STRING) AS zip_code