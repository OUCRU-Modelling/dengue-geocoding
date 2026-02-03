# ===== Set up ======
# install local version
# devtools::install("/Users/anhptq/Desktop/tidygeocoder")
library(tidygeocoder)
library(tidyverse)
library(qs2)

# ==== Util funcs =====
# geocode by batch of batch_size with sleep time in between batches
geocode_by_batch <- function(x, batch_size=5, sleep=1){
  indices <- seq(1, length(x), batch_size)
  # generate pointers/indices for each batch
  start <- indices
  end <- start + (batch_size -1)
  end[length(end)] <- min(end[length(end)], length(x))

  pmap(list(start, end), \(start, end){
    message(paste0("Geocode addresses at indices: ", start, " - ", end))
    out <- geo(address = x[start:end],
               method = "vietmap",
               api_options = list(
                 vietmap_display_type = 2
               ),
               full_results = TRUE,
               unique_only = FALSE)

    if(end < length(x)) Sys.sleep(sleep)

    out
  }) %>% bind_rows()
}

# cache_path: path to .qs file that store geocoded addresses
# colname: name of the column for address in df
# limit: max no. of addresses to be geocoded per geocode_df() call
# batch: no. addresses per tidygeocoder::geo() call. Vietmap may need "cool down" time per 100ish requests.
# sleep: sleep time between batches (in seconds)
geocode_df <- function(df, cache_path,
                       colname = "raw_addr",
                       limit=200,
                       batch = 100,
                       sleep = 60
                       ){
  # ----- Load cache ------
  cached_dat <- if(file.exists(cache_path)){
    qs_read(cache_path)
  } else{
    message("Cache not found")
    tibble()
  }
  if(nrow(cached_dat)>0 && !(colname %in% colnames(cached_dat)))
    warning(paste0("Column `", colname, "` not found in cached data"))

  # ---- Get addresses to geocode -----
  to_geocode <- df %>%
    select(colname) %>%
    unique() %>%
    anti_join(cached_dat %>% select(colname))

  # ---- Geocode data -----
  limit <- if(is.na(limit) | is.null(limit)) nrow(df) else min(nrow(df), limit)
  batch <- min(batch, limit)
  out <- to_geocode %>%
    head(n = limit) %>%
    mutate(
      geo = geocode_by_batch(raw_addr, batch_size = batch, sleep = sleep)
    ) %>%
    unnest(geo)

  # ------ Cache output -------
  new_cache <- bind_rows(cached_dat,
                         out) %>%
    unique()
  qs_save(new_cache, cache_path)

  new_cache
}





