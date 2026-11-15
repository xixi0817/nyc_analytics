-- Date dimension shared by DOB permits and 311 complaints (conformed)
-- Grain: one row per calendar date
-- Table name in BigQuery stays dim_date (file is named g4_ to avoid clashing with HW4's dim_date)
{{ config(alias='dim_date') }}

-- Build initial CTEs for Jinja syntax to make refs to staging models easier
WITH stg_dob AS (
    SELECT * FROM {{ ref('stg_dob_permit') }}
),

stg_311 AS (
    SELECT * FROM {{ ref('stg_nyc311_complaint') }}
),

-- Union dates from the staging data together, collecting all possible dates
all_dates AS (

    -- DOB permits: date roles referenced by fact_dob_permit
    SELECT DISTINCT filing_date AS full_date
    FROM stg_dob
    WHERE filing_date IS NOT NULL

    UNION DISTINCT

    SELECT DISTINCT issuance_date AS full_date
    FROM stg_dob
    WHERE issuance_date IS NOT NULL

    UNION DISTINCT

    SELECT DISTINCT expiration_date AS full_date
    FROM stg_dob
    WHERE expiration_date IS NOT NULL

    UNION DISTINCT

    -- 311 complaints: date roles referenced by fact_311_complaint
    SELECT DISTINCT CAST(created_date AS DATE) AS full_date
    FROM stg_311
    WHERE created_date IS NOT NULL

    UNION DISTINCT

    SELECT DISTINCT CAST(closed_date AS DATE) AS full_date
    FROM stg_311
    WHERE closed_date IS NOT NULL

),

-- Date attributes; fiscal year = calendar year (Jan to Dec), per M3 annotation
date_dimension AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key(['full_date']) }} AS date_key,

        full_date,
        EXTRACT(YEAR FROM full_date) AS year,
        EXTRACT(QUARTER FROM full_date) AS quarter,
        EXTRACT(MONTH FROM full_date) AS month,
        FORMAT_DATE('%B', full_date) AS month_name,
        EXTRACT(DAYOFWEEK FROM full_date) AS day_of_week,
        EXTRACT(DAY FROM full_date) AS day_of_month,
        FORMAT_DATE('%A', full_date) AS day_name,
        EXTRACT(DAYOFWEEK FROM full_date) IN (1, 7) AS is_weekend,
        EXTRACT(YEAR FROM full_date) AS fiscal_year

    FROM all_dates

),

-- Null placeholder row: fact tables COALESCE a null source date to this key
-- Keeps all fact and date_dim joins INNER JOINs safely (Kimball convention)
null_placeholder AS (

    SELECT
        '-1' AS date_key,
        CAST(NULL AS DATE) AS full_date,
        CAST(NULL AS INT64) AS year,
        CAST(NULL AS INT64) AS quarter,
        CAST(NULL AS INT64) AS month,
        CAST(NULL AS STRING) AS month_name,
        CAST(NULL AS INT64) AS day_of_week,
        CAST(NULL AS INT64) AS day_of_month,
        CAST(NULL AS STRING) AS day_name,
        CAST(NULL AS BOOLEAN) AS is_weekend,
        CAST(NULL AS INT64) AS fiscal_year
)

SELECT * FROM date_dimension

UNION ALL
SELECT * FROM null_placeholder