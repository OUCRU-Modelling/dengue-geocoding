library(optparse)
source("R/geocoding_fns.R")

# ======= Handle script ======
option_list <- list(
  make_option("--limit", action="store", default=200,
              help="max number of addresses to be geocoded via API call"),
  make_option("--batch", action="store", default=100,
              help="number of API calls before cooldown"),
  make_option("--sleep", action="store", default=62,
              help="cooldown time between batches of geocoding"),
  make_option("--city_id", action="store", default=12,
              help="a VietMap cityId to filter geocoding result"),

  make_option("--to_geocode", action="store", default="./data/cached/to_geocode_df.qs",
              help="path to .qs file that store the addresses to be geocoded"),
  make_option("--generate_to_geocode", action="store", default="./codes/02_generate_to_geocode.R",
              help="path to .R file that generate the data to be geocoded (if to_geocode was not found)"),
  make_option("--cache", action="store", default="./data/cached/geocoded_addr.qs",
              help="path to .qs file that store the data.frame of geocoded address"),
  make_option("--cache_failed", action="store", default="./data/cached/failed_geocode_addr.qs",
              help="path to .qs file that store the addresses that failed geocoding")
)

opt <- parse_args(
  OptionParser(option_list = option_list))

# Settings for related data/file
PATH_TO_GEOCODE_DF <- opt$to_geocode
PATH_CACHE <- opt$cache
PATH_CACHE_FAILED <- opt$cache_failed
PATH_GENERATE_TO_GEOCODE <- opt$generate_to_geocode

# Settings for geocoding using Vietmap API
LIMIT <- opt$limit # max no. of addresses to be geocoded via Vietmap API call per geocode_df() call
BATCH <- opt$batch # no. addresses per tidygeocoder::geo() call. Vietmap need "cool down" time per 100ish requests (free tier).
SLEEP <- opt$sleep # sleep time between batches (in seconds)
CITY_ID <- opt$city_id # City ID for filtering geocode result

# ======= Data processing =======
to_geocode_df <- if(!file.exists(PATH_TO_GEOCODE_DF)){
  clean_dat <- source(PATH_GENERATE_TO_GEOCODE)
  clean_dat$value
}else{
  qs_read(PATH_TO_GEOCODE_DF)
}

# ====== Geocoding data =========
# Geocoding using VietMap API ------
api_out <- to_geocode_df %>%
  filter(!is.na(diachi)) %>%
  geocode_df(
    cache_path = PATH_CACHE,
    failed_cache_path = PATH_CACHE_FAILED,
    colname = "raw_addr",
    limit = LIMIT,
    batch = BATCH,
    sleep = SLEEP,
    city_id = CITY_ID
  )

message("Vietmap geocoding: ", api_out$msg)

