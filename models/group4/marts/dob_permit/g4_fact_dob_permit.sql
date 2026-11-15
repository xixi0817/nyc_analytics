-- BigQuery table name: fact_dob_permit
{{ config(alias='fact_dob_permit') }}

-- Grain: one row per DOB permit issuance (permit_si_no)
WITH stg AS (
    SELECT * FROM {{ ref('stg_dob_permit') }}
)

SELECT
    -- Surrogate key for the fact row
    {{ dbt_utils.generate_surrogate_key(['stg.permit_si_no']) }} AS dob_permit_key,
    stg.permit_si_no,

    -- Foreign keys: look up each dim, use '-1' when no match
    COALESCE(loc.location_key, '-1') AS location_key,
    COALESCE(pt.permit_type_key, '-1') AS permit_type_key,
    COALESCE(ps.permit_status_key, '-1') AS permit_status_key,
    COALESCE(pr.property_type_key, '-1') AS property_type_key,
    COALESCE(ow.owner_type_key, '-1') AS owner_type_key,
    COALESCE(d_filing.date_key, '-1') AS filing_date_key,
    COALESCE(d_issue.date_key, '-1') AS issuance_date_key,
    COALESCE(d_expire.date_key, '-1') AS expiration_date_key,

    -- Degenerate dimensions kept on the fact
    stg.job_number,
    stg.job_doc_number,
    stg.permit_sequence,
    stg.bin_number,
    stg.bbl,

    -- Measures
    DATE_DIFF(stg.expiration_date, stg.issuance_date, DAY) AS permit_duration_days,
    1 AS permit_count

FROM stg
-- Join location on borough + zip (null safe), skip the placeholder row
LEFT JOIN {{ ref('g4_dim_location') }} loc
    ON loc.location_key != '-1'
    AND stg.borough IS NOT DISTINCT FROM loc.borough
    AND stg.zip_code IS NOT DISTINCT FROM loc.zip_code
-- Join permit type on job type + permit type + subtype
LEFT JOIN {{ ref('g4_dim_permit_type') }} pt
    ON pt.permit_type_key != '-1'
    AND stg.job_type IS NOT DISTINCT FROM pt.job_type
    AND stg.permit_type IS NOT DISTINCT FROM pt.permit_type
    AND stg.permit_subtype IS NOT DISTINCT FROM pt.permit_subtype
-- Join permit status on filing status + permit status
LEFT JOIN {{ ref('g4_dim_permit_status') }} ps
    ON ps.permit_status_key != '-1'
    AND stg.filing_status IS NOT DISTINCT FROM ps.filing_status
    AND stg.permit_status IS NOT DISTINCT FROM ps.permit_status
-- Join property type on building type + residential flag
LEFT JOIN {{ ref('g4_dim_property_type') }} pr
    ON pr.property_type_key != '-1'
    AND stg.bldg_type IS NOT DISTINCT FROM pr.bldg_type
    AND stg.residential IS NOT DISTINCT FROM pr.residential
-- Join owner type on business type + non profit flag
LEFT JOIN {{ ref('g4_dim_owner_type') }} ow
    ON ow.owner_type_key != '-1'
    AND stg.owner_business_type IS NOT DISTINCT FROM ow.owner_business_type
    AND stg.non_profit IS NOT DISTINCT FROM ow.non_profit
-- Role playing date dim: filing, issuance, expiration
LEFT JOIN {{ ref('g4_dim_date') }} d_filing
    ON d_filing.full_date = stg.filing_date
LEFT JOIN {{ ref('g4_dim_date') }} d_issue
    ON d_issue.full_date = stg.issuance_date
LEFT JOIN {{ ref('g4_dim_date') }} d_expire
    ON d_expire.full_date = stg.expiration_date