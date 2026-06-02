source("R/gen_mapping_key.R")
library(readxl)

# ========== Load incidence data (with geocode) ===========
old_area_raw_incidence_2017_2025 <- bind_rows(
  map(excel_sheets("./data/incidence/incidence_2017_2025.xlsx"),
      ~ read_excel("./data/incidence/incidence_2017_2025.xlsx", sheet = .x)),
  map(excel_sheets("./data/incidence/incidence_bd_vt_2017_2025.xlsx"),
      ~ read_excel("./data/incidence/incidence_bd_vt_2017_2025.xlsx", sheet = .x))
)

# bind_rows(
#   qs_read("data/cached/failed_geocode_addr.qs"),
#   qs_read("data/cached/failed_geocoded_aug2025_df.qs"),
#   qs_read("data/cached/failed_geocoded_bd_vt_df.qs")
# )

# ========== Check geocode old commune consistency ==========
# Compare the consistency between:
# 1. Manual mapping of commune names to 2023 GISvn polygons
# 2. Geocode-based mapping to 2023 GISvn polygons

# generate key for manual mapping
preprocess_b4_merge <- generate_key_dat_to_2023(
  old_area_raw_incidence_2017_2025,
  bind_rows(
    hcmc_shapefiles$commune_312,
    hcmc_shapefiles$commune_binhduong,
    hcmc_shapefiles$commune_br_vt
  )
)

# create id for each polygon
b4_merge_sf <- preprocess_b4_merge$sf %>% mutate(
  polygon_id = 1:n()
)
# add .row_id
preprocess_incidence <- preprocess_b4_merge$dat %>%
  ungroup() %>%
  mutate(
    .row_id = row_number()
  )

## -------- Manual mapping -------------
# manually assign incidence to each polygon by name
manual_mapping <- full_join(
  preprocess_incidence,
  b4_merge_sf %>%
    as_tibble() %>%
    select(-geometry),
  by = c("city_key", "district_key", "commune_key"),
  relationship = "many-to-one"
) %>%
  select(.row_id, long, lat, polygon_id) %>%
  rename(
    address_polygon_id = polygon_id
  )

## -------- Coordinate mapping -------------
# handle cases where coordinate is right on the border between 2 polygons
# prioritize results that are consistent with the manual mapping result
coordinate_points <- manual_mapping[!is.na(manual_mapping$long), ]  %>%
  st_as_sf(
    coords = c("long", "lat"),
    crs = st_crs("EPSG:4326"),
    remove = FALSE
  )
coordinate_hits <- st_covered_by(coordinate_points, b4_merge_sf)

choose_coordinate_match <- function(containing_rows, address_id) {
  if (!length(containing_rows)) {
    return(NA_integer_)
  }
  candidate_ids <- b4_merge_sf$polygon_id[containing_rows]
  if (address_id %in% candidate_ids) address_id else candidate_ids[1]
}

coordinate_match_id <- map2_int(
  coordinate_hits,
  coordinate_points$address_polygon_id,
  choose_coordinate_match
)

coordinate_mapping <- coordinate_points %>%
  st_drop_geometry() %>%
  ungroup() %>%
  select(.row_id) %>%
  mutate(
    coordinate_polygon_id = coordinate_match_id
  )

compare_address_coordinate_mapping <- preprocess_incidence %>%
  # Get the polygon info from address-based mapping
  left_join(
    manual_mapping %>% select(-long, -lat) %>%
      left_join(
        b4_merge_sf %>%
          st_drop_geometry() %>%
          select(polygon_id, name_2, name_3) %>%
          rename(address_commune = name_3, address_district = name_2),
        by = join_by(address_polygon_id == polygon_id)
      ),
    by = ".row_id"
  ) %>%
  # Get the polygon info from coordinate-based mapping
  left_join(
    coordinate_mapping %>%
      left_join(
        b4_merge_sf %>%
          st_drop_geometry() %>%
          select(polygon_id, name_2, name_3) %>%
          rename(coordinate_commune = name_3, coordinate_district = name_2),
        by = join_by(coordinate_polygon_id == polygon_id)
      ),
    by = ".row_id"
  ) %>%
  select(
    .row_id, dia_chi, phuong_xa_cu, quan_huyen_cu, thanh_pho_cu,
    diachi_api, long, lat,
    address_polygon_id, coordinate_polygon_id,
    address_commune, address_district, coordinate_commune, coordinate_district
  )

## --------- Summarize ---------
compare_address_coordinate_mapping %>%
  group_by(thanh_pho_cu) %>%
  summarize(
    with_geocode = sum(!is.na(long)),
    with_coordinate_polygon = sum(!is.na(coordinate_polygon_id)),
    geocode_outside_shape = sum(!is.na(long) & is.na(coordinate_polygon_id), na.rm = TRUE),
    with_address_polygon = sum(!is.na(address_polygon_id)),
    matched = sum(address_polygon_id == coordinate_polygon_id, na.rm = TRUE),
    mismatched = sum(address_polygon_id != coordinate_polygon_id, na.rm = TRUE),
    cant_assign = sum(is.na(coordinate_polygon_id) & is.na(address_polygon_id)),
    total = n(),
    matched_prop = matched/with_geocode
  ) %>%
  select(thanh_pho_cu, total, with_geocode, matched, matched_prop)

# NOTE: using GISvn --> 25,404 mismatched as opposed to 33,045 mismatched
# save the mismatch result here
# compare_address_coordinate_mapping %>%
#   filter(
#     coordinate_polygon_id != address_polygon_id
#   ) %>%
#   writexl::write_xlsx("data/posthoc_check/mismatched_raw_api_gisvn.xlsx")

# ========== Check mapping to GADM ==========
# Check the mapping between data and GADM
# generate key for manual mapping
preprocess_gadm_key <- generate_key_dat_to_gadm(
  old_area_raw_incidence_2017_2025,
  bind_rows(
    hcmc_shapefiles$commune_322,
    hcmc_shapefiles$commune_binhduong,
    hcmc_shapefiles$commune_br_vt
  )
)

## -------- Get communes that are in GADM but not in the data -------------
full_join(
  preprocess_gadm_key$dat %>%
    select(phuong_xa_cu, quan_huyen_cu, thanh_pho_cu, ends_with("_key")) %>%
    unique() %>%
    arrange(city_key, district_key, commune_key) ,
  preprocess_gadm_key$sf %>%
    mutate(
      polygon_id = 1:n()
    ) %>%
    as_tibble() %>%
    select(name_1, name_2, name_3, polygon_id, ends_with("_key")),
  by = c("city_key", "district_key", "commune_key"),
  relationship = "many-to-one"
) %>%
  filter(is.na(phuong_xa_cu) | is.na(polygon_id))

# ========== Check geocode new commune =============
# Do the following
# - Manually map old communes (in incidence data) to new commune (after July 2025 merge)
# - Compare the manual mapping to the new commune returned by geocode API

## --------- Manual mapping to new commune ------
# generate join keys
preprocessed_dat <- generate_key_dat_to_2025(old_area_raw_incidence_2017_2025,
                                            old_new_map)

# join incidence to lookup table
# - if all 3 keys available → join using all 3 keys
# - otherwise, use commune_key only (i.e. w/out 2023 intermediate)
three_key <- preprocessed_dat$dat %>%
  left_join(preprocessed_dat$mapping %>%
              filter(!is.na(district_key), !is.na(city_key)),
            by = c("city_key", "district_key", "commune_key"))
mapped_incidence <- bind_rows(
  three_key %>% filter(!is.na(ten_xa_cu)),  # matched
  three_key %>% filter( is.na(ten_xa_cu)) %>%  # unmatched → try fallback
    left_join(preprocessed_dat$mapping %>% filter(is.na(district_key), is.na(city_key)) %>%
                select(-city_key, -district_key), by = "commune_key")
)

## ------- Summarize ---------
mapped_incidence %>%
  select(dia_chi,
         phuong_xa_cu, quan_huyen_cu, thanh_pho_cu,
         diachi_api, long, lat,
         px_moi,
         ten_xa_cu, ten_huyen_cu, ten_xa_moi, loai_sap_nhap
  ) %>%
  mutate(
    matched = ten_xa_moi == px_moi
  ) %>%
  filter(
    loai_sap_nhap == "toan phan"
  ) %>%
  group_by(
    thanh_pho_cu
  ) %>%
  summarize(
    no_geocode = sum(is.na(long)),
    with_geocode = sum(!is.na(long)),
    matched = sum(matched, na.rm=TRUE),
    total = n(),
    matched_prop = (matched)/(n() - no_geocode)
  )

# mapped_incidence %>%
#   filter(
#     loai_sap_nhap == "toan phan"
#   ) %>%
#   select(dia_chi,
#          phuong_xa_cu, quan_huyen_cu, thanh_pho_cu,
#          diachi_api, long, lat,
#          px_moi,
#          ten_xa_cu, ten_huyen_cu, ten_xa_moi, loai_sap_nhap
#   ) %>%
#   filter(px_moi != ten_xa_moi) %>%
#   View()
