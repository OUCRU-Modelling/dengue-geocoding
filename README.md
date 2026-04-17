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

-   `02_generate_to_geocode.R` extract unique addresses for geocoding

    -   Output: `data/cached/to_geocoded_df.qs`

    -   The geocoding process is handled separately

-   `03_export_geocoded_incidence.R` export incidence data with the GPS coordinates

### Data geocoding (`geocoding/`)

Main scripts:

-   `main.R` script for geocoding addresses using VietMap API

    -   Input: `data/cached/to_geocoded_df.qs`

    -   Output:

        -   `data/cached/geocoded_addr.qs` successfully geocoded addresses

        -   `data/cached/failed_geocoded_addr.qs` addresses that failed geocoding

-   `geocode_script.sh` bash script to dispatch the geocoding script on OUCRU's HPC
