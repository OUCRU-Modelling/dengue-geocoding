# Dengue incidence address geocoding in HCMC

This repo is part of the "Spatiotemporal modelling of dengue incidence in HCMC" project, funded by OUCRU-PSC.

The project proposed duration is Dec 2025 - Nov 2026

## Dependencies

This project uses `OUCRU-Modelling/tidygeocoder`, a fork of the `tidygeocoder` R package that implements Vietmap's geocoding API.

## Navigating the repo

```         
dengue-geocoding/
├── R/            Helper functions
├── codes/        Data cleaning and exporting workflow
├── data/         Input and output data
├── geocoding/    Script for geocoding
└── notebooks/    .Rmd files for visualizing incidence data
```

### Data cleaning and exporting (`codes/`)

Main workflow:

-   `01_clean_incidence_data.R` clean and standardize raw incidence data

-   `02_generate_to_geocode.R` and `02_generate_to_geocode_bd_vt.R`: extract unique addresses for geocoding

    -   Output:

        -   `data/cached/to_geocode_df.qs` HCMC data before 2025 merge

        -   `data/cached/to_geocode_bd_vt_df.qs` Binh Duong, Vung Tau data before 2025 merge

    -   The geocoding process is handled separately

-   `04_export_geocoded_*.R` export incidence data with the GPS coordinates

-   `05_generate_to_geocode_aug2025.R` extracting addresses (after 2025 merge) for geocoding, also checks against existing geocoded results to avoid duplicate geocoding.

-   `06_export_geocoded_aug2025.R` export post-reform incidence data with the GPS coordinates

-   `07_export_data_w_sf.R` export data bundle (`.rds`) with incidence data and lookup table for shapefiles

-   `08_postreform_by_mapping.R` update post-reform commune when pre-reform was not splitted during merge

-   `99_*.R` miscellaneous posthoc checks

### Data geocoding (`geocoding/`)

Main scripts:

-   `main.R` script for geocoding addresses using VietMap API

    -   Input: `data/cached/to_geocoded_df.qs`

    -   Output:

        -   `data/cached/geocoded_addr.qs` successfully geocoded addresses

        -   `data/cached/failed_geocoded_addr.qs` addresses that failed geocoding

-   `geocode_script.sh` bash script to dispatch the geocoding script on OUCRU's HPC
