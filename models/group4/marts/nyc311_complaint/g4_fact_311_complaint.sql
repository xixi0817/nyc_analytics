-- BigQuery table name: fact_311_complaint
{{ config(alias='fact_311_complaint') }}

-- Grain: one row per 311 service request
WITH stg AS (
    SELECT * FROM {{ ref('stg_nyc311_complaint') }}
)

SELECT
    -- Surrogate key for the fact row
    {{ dbt_utils.generate_surrogate_key(['stg.unique_key']) }} AS complaint_key,
    stg.unique_key,

    -- Foreign keys: look up each dim, use '-1' when no match
    COALESCE(loc.location_key, '-1') AS location_key,
    COALESCE(ct.complaint_type_key, '-1') AS complaint_type_key,
    COALESCE(cs.complaint_status_key, '-1') AS complaint_status_key,
    COALESCE(d_created.date_key, '-1') AS created_date_key,
    COALESCE(d_closed.date_key, '-1') AS closed_date_key,

    -- Descriptive fields kept on the fact
    stg.bbl,
    stg.resolution_description,
    stg.latitude,
    stg.longitude,

    -- Measures
    1 AS complaint_count,
    DATE_DIFF(DATE(stg.closed_date), DATE(stg.created_date), DAY) AS days_to_close

FROM stg
-- Join location on borough + zip (null safe), skip the placeholder row
LEFT JOIN {{ ref('g4_dim_location') }} loc
    ON loc.location_key != '-1'
    AND stg.borough IS NOT DISTINCT FROM loc.borough
    AND stg.zip_code IS NOT DISTINCT FROM loc.zip_code
-- Join complaint type on type + descriptor
LEFT JOIN {{ ref('g4_dim_complaint_type') }} ct
    ON ct.complaint_type_key != '-1'
    AND stg.complaint_type IS NOT DISTINCT FROM ct.complaint_type
    AND stg.descriptor IS NOT DISTINCT FROM ct.descriptor
-- Join complaint status
LEFT JOIN {{ ref('g4_dim_complaint_status') }} cs
    ON cs.complaint_status_key != '-1'
    AND stg.status IS NOT DISTINCT FROM cs.complaint_status
-- Role playing date dim: created date and closed date
LEFT JOIN {{ ref('g4_dim_date') }} d_created
    ON d_created.full_date = DATE(stg.created_date)
LEFT JOIN {{ ref('g4_dim_date') }} d_closed
    ON d_closed.full_date = DATE(stg.closed_date)