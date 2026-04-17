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
  make_option("--cache", action="store", default="./data/cached/geocoded_addr.qs",
              help="path to .qs file that store the data.frame of geocoded address")
)

opt <- parse_args(
  OptionParser(option_list = option_list))

# ======= Data processing =======
to_geocode_df <- if(!file.exists("./data/cached/to_geocode_df.qs")){
  clean_dat <- source("./codes/02_generate_to_geocode.R")
  clean_dat$value
}else{
  qs_read("./data/cached/to_geocode_df.qs")
}

# ====== Geocoding data =========
# Manual geocoding ------
# If specific address is not available --> use centroid of ward/district as geocode
# TODO: Manual geocoding is deprecated, leave addresses with na diachi as is
# Also update the path to shapefile

# manual_out <- to_geocode_df %>%
#   filter(is.na(diachi)) %>%
#   geocode_manual(
#     addr_col = "raw_addr",
#     admin3_col = "px",
#     admin2_col = "qh",
#     na_label = c("KHONG RO", "THI TRAN"),
#     admin3_gadm = "./data/gadm/gadm41_VNM_3_pk.rds",
#     admin2_gadm = "./data/gadm/gadm41_VNM_2_pk.rds"
#   )
#
# qs_save(manual_out, "./data/cached/geocoded_manual.qs")
# message("Manual geocoding: ", nrow(manual_out$out), " addresses successfully geocoded, while ",
#         nrow(manual_out$failed), " failed")


# Geocoding using API call ------
# Settings for geocoding using Vietmap API
LIMIT <- opt$limit # max no. of addresses to be geocoded via Vietmap API call per geocode_df() call
BATCH <- opt$batch # no. addresses per tidygeocoder::geo() call. Vietmap need "cool down" time per 100ish requests (free tier).
SLEEP <- opt$sleep # sleep time between batches (in seconds)
path_to_cache <- opt$cache

api_out <- to_geocode_df %>%
  filter(!is.na(diachi)) %>%
  geocode_df(
    cache_path = path_to_cache,
    failed_cache_path = "./data/cached/failed_geocode_addr.qs",
    colname = "raw_addr",
    limit = LIMIT,
    batch = BATCH,
    sleep = SLEEP
  )
message("Vietmap geocoding: ", api_out$msg)

