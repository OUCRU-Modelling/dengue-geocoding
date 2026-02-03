# TODO: turn this into a script

source("geocoding/geocoding_fns.R")
source("geocoding/clean_data_fns.R")

# ======= Data processing =======
df_2000_2016 <- ingest_xlsx("./data/incidence/2000_2016_updated.xlsx")


test_clean_df <- df_2000_2016 %>% clean_xlsx(remove_accent = FALSE)
test_no_accent <- df_2000_2016 %>% clean_xlsx(remove_accent = TRUE)

test_clean_addr <- test_clean_df %>% get_clean_addr(colname = "raw_addr")
test_clean_no_accent <- test_no_accent %>% get_clean_addr(colname = "raw_addr")

# Note: with accent 147927 -> 135387 after get_clean_addr()
# Note: without accent 147927 -> 134081 after get_clean_addr()

# ====== Geocoding data =========
LIMIT <- 1 # max no. of addresses to be geocoded per geocode_df() call
BATCH <- 1 # no. addresses per tidygeocoder::geo() call. Vietmap need "cool down" time per 100ish requests (free tier).
SLEEP <- 60 # sleep time between batches (in seconds)

out <- test_clean_df %>%
  head(n=50) %>%
  geocode_df(
    cache_path = "./data/cached/geocoded_addr.qs",
    colname = "raw_addr",
    limit = LIMIT,
    batch = BATCH,
    sleep = SLEEP
  )
nrow(out)
