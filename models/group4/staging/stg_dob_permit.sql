-- Clean and standardize DOB Permit Issuance data
-- One row per permit issuance record (initial or renewal)

WITH source AS (
    SELECT * FROM {{ source('group4_raw', 'dob_permit_raw') }}
), -- Short name for the raw DOB table

cleaned AS (
    SELECT
        -- Get all columns from source, except ones we're transforming below
        * EXCEPT (
            permit_si_no,
            job__,
            job_doc___,
            permit_sequence__,
            bin__,
            filing_date,
            issuance_date,
            expiration_date,
            job_type,
            permit_type,
            permit_subtype,
            filing_status,
            permit_status,
            bldg_type,
            residential,
            owner_s_business_type,
            non_profit,
            borough,
            block,
            lot,
            bbl,
            zip_code,
            community_board,
            gis_council_district,
            gis_latitude,
            gis_longitude
        ),

        -- Identifiers (clearer names than the API field names)
        CAST(permit_si_no AS STRING) AS permit_si_no,
        CAST(job__ AS STRING) AS job_number,
        CAST(job_doc___ AS STRING) AS job_doc_number,
        CAST(permit_sequence__ AS STRING) AS permit_sequence,
        CAST(bin__ AS STRING) AS bin_number,

        -- Dates: source is text in MM/DD/YYYY format, convert to DATE
        SAFE.PARSE_DATE('%m/%d/%Y', filing_date) AS filing_date,
        SAFE.PARSE_DATE('%m/%d/%Y', issuance_date) AS issuance_date,
        SAFE.PARSE_DATE('%m/%d/%Y', expiration_date) AS expiration_date,

        -- Permit details: trim spaces and use upper case so values group correctly
        UPPER(TRIM(CAST(job_type AS STRING))) AS job_type,
        UPPER(TRIM(CAST(permit_type AS STRING))) AS permit_type,
        UPPER(TRIM(CAST(permit_subtype AS STRING))) AS permit_subtype,
        UPPER(TRIM(CAST(filing_status AS STRING))) AS filing_status,
        UPPER(TRIM(CAST(permit_status AS STRING))) AS permit_status,

        -- Property: residential is only YES or empty in the source
        -- YES becomes TRUE, empty stays NULL (not FALSE), per M3 annotation
        CAST(bldg_type AS STRING) AS bldg_type,
        CASE
            WHEN UPPER(TRIM(CAST(residential AS STRING))) = 'YES' THEN TRUE
            ELSE NULL
        END AS residential,

        -- Owner: Y becomes TRUE, N becomes FALSE, empty stays NULL
        CAST(owner_s_business_type AS STRING) AS owner_business_type,
        CASE
            WHEN UPPER(TRIM(CAST(non_profit AS STRING))) = 'Y' THEN TRUE
            WHEN UPPER(TRIM(CAST(non_profit AS STRING))) = 'N' THEN FALSE
            ELSE NULL
        END AS non_profit,

        -- Location: standardized borough, same values as the 311 staging model
        CASE
            WHEN UPPER(TRIM(borough)) = 'MANHATTAN' THEN 'Manhattan'
            WHEN UPPER(TRIM(borough)) = 'BRONX' THEN 'Bronx'
            WHEN UPPER(TRIM(borough)) = 'BROOKLYN' THEN 'Brooklyn'
            WHEN UPPER(TRIM(borough)) = 'QUEENS' THEN 'Queens'
            WHEN UPPER(TRIM(borough)) = 'STATEN ISLAND' THEN 'Staten Island'
            ELSE 'Unspecified'
        END AS borough,

        CAST(block AS STRING) AS block,
        CAST(lot AS STRING) AS lot,

        -- Keep BBL only when it is a valid 10 digit value
        CASE
            WHEN REGEXP_CONTAINS(TRIM(CAST(bbl AS STRING)), r'^\d{10}$') THEN TRIM(CAST(bbl AS STRING))
            ELSE NULL
        END AS bbl,

        -- Keep the first 5 digits of the zip code, otherwise NULL
        CASE
            WHEN REGEXP_CONTAINS(TRIM(CAST(zip_code AS STRING)), r'^\d{5}') THEN LEFT(TRIM(CAST(zip_code AS STRING)), 5)
            ELSE NULL
        END AS zip_code,

        -- Clearer names for the GIS columns
        CAST(community_board AS STRING) AS community_board,
        CAST(gis_council_district AS STRING) AS council_district,
        CAST(gis_latitude AS FLOAT64) AS latitude,
        CAST(gis_longitude AS FLOAT64) AS longitude,

        -- Metadata
        CURRENT_TIMESTAMP() AS _stg_loaded_at

    FROM source

    -- Filters: fixed project date range 01/01/2020 to 09/10/2026 (per M3 feedback)
    WHERE permit_si_no IS NOT NULL
    AND SAFE.PARSE_DATE('%m/%d/%Y', issuance_date) BETWEEN DATE '2020-01-01' AND DATE '2026-09-10'

    -- Deduplicate: keep one row per permit_si_no
    QUALIFY ROW_NUMBER() OVER (PARTITION BY permit_si_no ORDER BY issuance_date DESC) = 1
)

SELECT * FROM cleaned
-- All should be part of this table after running: stg_dob_permit