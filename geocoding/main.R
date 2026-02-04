# TODO: make this a script with args

source("geocoding/geocoding_fns.R")
source("geocoding/clean_data_fns.R")

# ======= Data processing =======
df_2000_2016 <- ingest_xlsx("./data/incidence/2000_2016_updated.xlsx")

test_clean_df <- df_2000_2016 %>% clean_xlsx(remove_accent = FALSE)
test_no_accent <- df_2000_2016 %>% clean_xlsx(remove_accent = TRUE)

# Test number of addresses w/ and w/out removing accents
# test_clean_addr <- test_clean_df %>% get_clean_addr(colname = "raw_addr")
# test_clean_no_accent <- test_no_accent %>% get_clean_addr(colname = "raw_addr")
# Note: with accent 147927 -> 135387 after get_clean_addr()
# Note: without accent 147927 -> 134081 after get_clean_addr()

# ====== Geocoding data =========
# Manual geocoding ------
# If specific address is not available --> use centroid of ward/district as geocode
manual_out <- test_clean_df %>%
  filter(is.na(diachi)) %>%
  geocode_manual(
    addr_col = "raw_addr",
    admin3_col = "px",
    admin2_col = "qh",
    na_label = c("KHONG RO", "THI TRAN"),
    admin3_gadm = "./data/gadm/gadm41_VNM_3_pk.rds",
    admin2_gadm = "./data/gadm/gadm41_VNM_2_pk.rds"
  )

message("Manual geocoding: ", nrow(manual_out$out), " addresses successfully geocoded, while ",
        nrow(manual_out$failed), " failed")

# Geocoding using API call ------
# Settings for geocoding using Vietmap API
LIMIT <- 1 # max no. of addresses to be geocoded via Vietmap API call per geocode_df() call
BATCH <- 1 # no. addresses per tidygeocoder::geo() call. Vietmap need "cool down" time per 100ish requests (free tier).
SLEEP <- 62 # sleep time between batches (in seconds)

api_out <- test_clean_df %>%
  filter(!is.na(diachi)) %>%
  geocode_df(
    cache_path = "./data/cached/geocoded_addr.qs",
    colname = "raw_addr",
    limit = LIMIT,
    batch = BATCH,
    sleep = SLEEP
  )

message("Vietmap geocoding: ", api_out$msg)
