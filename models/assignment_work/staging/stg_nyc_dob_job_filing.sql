-- Clean and standardize NYC Job filing applications request data
-- One row per job filing

WITH source AS (
   SELECT * FROM {{ source('raw', 'source_nyc_dob_job_apps') }}
), -- Easier to refer to the dbt reference to a long name table this way

cleaned AS (
   SELECT
       -- Get all columns from source, except ones we're transforming below
       -- To do cleaning on them or explicitly cast them as types just in case
       * EXCEPT (
           job_filing_number,
           job_type,
           filing_date,
           filing_status,
           current_status_date,
           first_permit_date,
           approved_date,
           signoff_date,
           house_no,
           street_name,
           postcode,
           borough,
           latitude,
           longitude,
           zip
           
       ),

       -- Identifiers
       CAST(job_filing_number AS STRING) AS job_filing_number,

       -- Date/Time
       CAST(filing_date AS TIMESTAMP) AS filing_date,
       CAST(current_status_date AS TIMESTAMP) AS current_status_date,
       CAST(approved_date AS TIMESTAMP) AS approved_date,
       CAST(first_permit_date AS TIMESTAMP) AS first_permit_date,
       CAST(signoff_date AS TIMESTAMP) AS signoff_date,

       -- Request details
       CAST(job_type AS STRING) AS job_type,
       CAST(filing_status AS STRING) AS filing_status,
       CAST(house_no AS STRING) AS house_no,
       CAST(street_name AS STRING) AS street_name,
       --CAST(postcode AS STRING) AS postcode,
       CAST(borough AS STRING) AS borough,
       CAST(latitude AS DECIMAL) AS latitude,
       CAST(longitude AS DECIMAL) AS longitude,
       

       -- Location - clean zip code, handling several common zip code data problems
       CASE
           WHEN UPPER(TRIM(CAST(postcode AS STRING))) IN ('N/A', 'NA') THEN NULL
           WHEN UPPER(TRIM(CAST(postcode AS STRING))) = 'ANONYMOUS' THEN 'Anonymous'
           WHEN LENGTH(CAST(postcode AS STRING)) = 5 THEN CAST(postcode AS STRING)
           WHEN LENGTH(CAST(postcode AS STRING)) = 9 THEN CAST(postcode AS STRING)
           WHEN LENGTH(CAST(postcode AS STRING)) = 10
               AND REGEXP_CONTAINS(CAST(postcode AS STRING), r'^\d{5}-\d{4}')
           THEN CAST(postcode AS STRING)
           ELSE NULL
       END AS zip,

       -- Location - standardized borough, just in case
         --CASE
             --WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
             --WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
             --WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
             --WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
             --WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
             --ELSE 'UNKNOWN or CITYWIDE'
         --END AS borough,

 
       -- Clearer column name as well for this one
        -- CAST(open_data_channel_type AS STRING) AS method_of_submission,

       -- Metadata
       CURRENT_TIMESTAMP() AS _stg_loaded_at

   FROM source

   -- Filters
   WHERE (filing_status = 'Approved' OR job_type LIKE '%Alteration%')
   AND job_filing_number IS NOT NULL
   AND CAST(filing_date AS DATE) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 YEAR)
   AND borough IS NOT NULL

   -- Deduplicate
   -- QUALIFY ROW_NUMBER() OVER (PARTITION BY unique_key ORDER BY created_date DESC) = 1
)

SELECT * FROM cleaned
-- All should be part of this table after running: dbt run --select stg_nyc_dob_job_filing
