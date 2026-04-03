# ===== Set up ======
# install local version
# devtools::install("/Users/anhptq/Desktop/tidygeocoder")
library(tidygeocoder)
library(tidyverse)
library(stringi)
library(qs2)
library(terra)
library(sf)

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
               custom_query = list(
                 "display_type" = 6,
                 "cityId"=12
               ),
               full_results = TRUE,
               unique_only = FALSE,
               min_time = 0.1 #time per request (set to 10 requests per sec here)
               )

    if(end < length(x)) Sys.sleep(sleep)

    if(nrow(out %>% filter(!is.na(long))) > 0){
      out <- out %>%
        rename(
          vietmap_district = district,
          vietmap_district_id = district_id,
          vietmap_ward = ward,
          vietmap_ward_id = ward_id,
          raw_addr = address
        ) %>%
        select(-name, -hs_num, -vietmap_street, -vietmap_city, -city_id)
    }else{
      out <- out %>%
        rename(
          raw_addr = address
        )
    }

    # save each batch just to make sure
    if (!dir.exists("./data/cached/batch/")) {
      dir.create("./data/cached/batch/")
    }
    qs_save(out, paste0("./data/cached/batch/idx_",start, "_", end, "_", Sys.time(), ".qs"))

    out
  }) %>% bind_rows()
}

# helper function to generate a tibble of district/ward and their centroid
get_centroid_df <- function(gadm_file,
                            select_cols = c("NAME_2", "NAME_3")){
  dat <- read_rds(gadm_file) %>%
    terra::unwrap()
  # keep polygons for hcm city only
  dat <- dat[dat$GID_1 == "VNM.25_1", ]

  dat %>%
    centroids(inside=TRUE) %>%
    st_as_sf() %>%
    mutate(
      long = st_coordinates(geometry)[,1],
      lat = st_coordinates(geometry)[,2]
    ) %>%
    as_tibble() %>%
    select( any_of( c(select_cols, "long", "lat") ) ) %>%
    # preprocess district, ward name
    mutate(across(where(is.character), \(str){
      str_to_upper(str) %>%
        stri_trans_general(id = "Latin-ASCII") %>%
        # make sure the name match that in the incidence data
        if_else(
          str_detect(., "\\d"),
          str_remove(., "(QUAN |PHUONG )"),
          .
        ) %>%
        str_pad(width = 2, side = "left", pad = "0")
    }))
}


# ========= Geocode functions ==========
# Manually geocode addresses given ward/district
# Return the centroid of the ward/district
geocode_manual <- function(df,
                           addr_col = "raw_addr",
                           admin3_col = "px",
                           admin2_col = "qh",
                           na_label = c("KHONG RO", "THI TRAN"),
                           admin3_gadm = "./data/gadm/gadm41_VNM_3_pk.rds",
                           admin2_gadm = "./data/gadm/gadm41_VNM_2_pk.rds"){

  # ------ Get the centroids -------
  admin3 <- get_centroid_df(admin3_gadm)
  admin2 <- get_centroid_df(admin2_gadm)

  # ------ Get addresses to geocode ------
  to_geocode <- df %>%
    select(all_of(c(addr_col, admin2_col, admin3_col))) %>%
    unique() %>%
    rename(
      qh = admin2_col,
      px = admin3_col
    ) %>%
    # require at least district or ward to geocode
    filter(!(px %in% na_label) | !(qh %in% na_label))

  # ------ Geocode manually (i.e., the centroid of district/ward) ------
  out <- to_geocode %>%
    # geocode using ward if available, fallback to district otherwise
    mutate(
      geocode_lvl = if_else(
        !(px %in% na_label),
        "admin3",
        "admin2"
      )
    ) %>%
    group_by(geocode_lvl) %>%
    group_modify(\(.x, .y){
      if(.y$geocode_lvl == "admin3"){
        return(
          .x %>%
            left_join(admin3, by =
                        join_by(px == NAME_3, qh == NAME_2))
        )
      }

      .x %>%
        left_join(admin2, by = join_by(qh == NAME_2))
    }) %>%
    ungroup() %>%
    select(-geocode_lvl)

  list(
    out = out %>% filter(!is.na(long), !is.na(lat)),
    failed = out %>% filter(is.na(long) | is.na(lat))
  )
}

# Geocode addresses and append new results to a cached file
# cache_path: path to .qs file that store geocoded addresses
# colname: name of the column for address in df
# limit: max no. of addresses to be geocoded via API call per geocode_df() call
# batch: no. addresses per tidygeocoder::geo() call. Vietmap API may need "cool down" time per 100ish requests (free tier).
# sleep: sleep time between batches (in seconds)
geocode_df <- function(df,
                         cache_path,
                         failed_cache_path,
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

    failed_dat <- if(file.exists(failed_cache_path)){
      qs_read(failed_cache_path)
    } else{
      message("Cache for failed addresses not found")
      tibble()
    }

    if(nrow(cached_dat)>0 && !(colname %in% colnames(cached_dat)))
      warning(paste0("Column `", colname, "` not found in cached data"))

    # ---- Get addresses to geocode -----
    to_geocode <- df %>%
      select(all_of(colname)) %>%
      unique()

    # exclude addresses that are already geocoded
    to_geocode <- if(nrow(cached_dat)>0){
      to_geocode %>% anti_join(cached_dat %>% select(all_of(colname)))
    }else{
      to_geocode
    }

    # exclude addresses that failed to be geocoded with Vietmap API
    to_geocode <- if(nrow(failed_dat)>0){
      to_geocode %>% anti_join(failed_dat %>% select(all_of(colname)))
    }else{
      to_geocode
    }


    # ---- Geocode data -----
    limit <- if(is.na(limit) | is.null(limit)) nrow(df) else min(nrow(df), limit)
    batch <- min(batch, limit)
    out <- to_geocode %>%
      head(n = limit) %>%
      pull(any_of(colname)) %>%
      geocode_by_batch(batch_size=batch, sleep=sleep)

    # only cache addresses that were successfully geocoded
    success <- out %>% filter(!is.na(long), !is.na(lat))
    fail <- out %>% filter(is.na(long) | is.na(lat))

    # ------ Cache output -------
    # cache new successfully geocoded address
    new_cache <- bind_rows(cached_dat,
                           success) %>%
      unique()
    qs_save(new_cache, cache_path)
    # also cache addresses that failed to b geocoded to avoid repeated api call
    new_failed_cache <- bind_rows(failed_dat,
                           fail) %>%
      unique()
    qs_save(new_failed_cache, failed_cache_path)

    list(
      out = new_cache,
      failed = fail,
      msg = paste0(
        nrow(success),
        " out of ",
        nrow(out),
        " addresses successfully geocoded and appended to cache"
      )
    )
  }
