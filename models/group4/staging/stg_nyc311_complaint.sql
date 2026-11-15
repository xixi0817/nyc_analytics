-- Clean and standardize NYC 311 General Construction/Plumbing complaints
-- One row per service request

WITH source AS (
    SELECT * FROM {{ source('group4_raw', 'nyc311_construction_raw') }}
), -- Short name for the raw 311 table

cleaned AS (
    SELECT
        -- Get all columns from source, except ones we're transforming below
        * EXCEPT (
            unique_key,
            created_date,
            closed_date,
            agency,
            agency_name,
            complaint_type,
            descriptor,
            status,
            resolution_description,
            incident_zip,
            borough,
            bbl,
            latitude,
            longitude
        ),

        -- Identifiers
        CAST(unique_key AS STRING) AS unique_key,

        -- Date/Time: NYC local time as published by NYC Open Data
        CAST(created_date AS TIMESTAMP) AS created_date,
        CAST(closed_date AS TIMESTAMP) AS closed_date,

        -- Request details
        CAST(agency AS STRING) AS agency,
        CAST(agency_name AS STRING) AS agency_name,
        CAST(complaint_type AS STRING) AS complaint_type,
        CAST(descriptor AS STRING) AS descriptor,
        UPPER(TRIM(CAST(status AS STRING))) AS status,
        CAST(resolution_description AS STRING) AS resolution_description,

        -- Location: rename incident_zip to zip_code to match the DOB staging model
        -- Keep the first 5 digits of the zip code, otherwise NULL
        CASE
            WHEN REGEXP_CONTAINS(TRIM(CAST(incident_zip AS STRING)), r'^\d{5}') THEN LEFT(TRIM(CAST(incident_zip AS STRING)), 5)
            ELSE NULL
        END AS zip_code,

        -- Location: standardized borough, same values as the DOB staging model
        CASE
            WHEN UPPER(TRIM(borough)) = 'MANHATTAN' THEN 'Manhattan'
            WHEN UPPER(TRIM(borough)) = 'BRONX' THEN 'Bronx'
            WHEN UPPER(TRIM(borough)) = 'BROOKLYN' THEN 'Brooklyn'
            WHEN UPPER(TRIM(borough)) = 'QUEENS' THEN 'Queens'
            WHEN UPPER(TRIM(borough)) = 'STATEN ISLAND' THEN 'Staten Island'
            ELSE 'Unspecified'
        END AS borough,

        -- Keep BBL only when it is a valid 10 digit value
        CASE
            WHEN REGEXP_CONTAINS(TRIM(CAST(bbl AS STRING)), r'^\d{10}$') THEN TRIM(CAST(bbl AS STRING))
            ELSE NULL
        END AS bbl,

        CAST(latitude AS FLOAT64) AS latitude,
        CAST(longitude AS FLOAT64) AS longitude,

        -- Metadata
        CURRENT_TIMESTAMP() AS _stg_loaded_at

    FROM source

    -- Filters: only General Construction/Plumbing complaints
    -- and the fixed project date range 01/01/2020 to 09/10/2026 (per M3 feedback)
    WHERE unique_key IS NOT NULL
    AND complaint_type = 'General Construction/Plumbing'
    AND DATE(created_date) BETWEEN DATE '2020-01-01' AND DATE '2026-09-10'

    -- Deduplicate: keep one row per unique_key
    QUALIFY ROW_NUMBER() OVER (PARTITION BY unique_key ORDER BY created_date DESC) = 1
)

SELECT * FROM cleaned
-- All should be part of this table after running: stg_nyc311_complaint