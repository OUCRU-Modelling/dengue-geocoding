# Code for preparing incidence data with similarity and the assigned polygon

# Packages ----------------------------------------------------------------
source("codes/00_packages.R", verbose=TRUE)
source("R/gen_mapping_key.R")
library(readxl)
library(stringdist)
library(tidylog)

# CRS definitions ----------------------------------------------------------
# Keep all sf objects in the raw longitude/latitude CRS used by the incidence
# coordinates and GADM source polygons.
raw_coordinate_crs <- st_crs("EPSG:4326")

# Prepare incidence data ---------------------------------------------------
## Step 1: read the 2017-2025 sources together ---------------------------
old_area_incidence_source_paths <- c(
  "./data/incidence/incidence_2017_2025.xlsx",
  "./data/incidence/incidence_bd_vt_2017_2025.xlsx",
  "./data/incidence/incidence_aug2025.xlsx"
)

old_area_raw_incidence_2017_2025 <- old_area_incidence_source_paths |>
  map(
    \(source_path) {
      map(
        excel_sheets(source_path),
        \(source_sheet) read_excel(source_path, sheet = source_sheet)
      )
    }
  ) |>
  list_flatten() |>
  bind_rows()

## Step 2: standardize the Vietnamese source field names  ------------
old_area_incidence_selected <- old_area_raw_incidence_2017_2025 %>%
  rename(
    date_of_birth = ngay_thang_nam_sinh,
    age = tuoi,
    address_inputted = dia_chi,
    method_of_care = hinh_thuc_dieu_tri,
    severity = phan_do_benh,
    date_of_symptom = ngay_khoi_phat_trieu_chung,
    date_hosp = ngay_nhap_vien_kham_benh,
    date_of_report = ngay_bao_cao,
    year = nam,
    month = thang,
    old_district = quan_huyen_cu,
    old_commune_ward = phuong_xa_cu,
    old_city = thanh_pho_cu,
    api_address = diachi_api,
    longitude = long,
    latitude = lat,
    new_commune_ward = px_moi
  ) %>%
  mutate(
    # The August 2025 workbook names this field differently from the other
    # incidence workbooks.
    new_commune_ward = coalesce(new_commune_ward, phuong_xa_moi)
  ) %>%
  select(
    address_inputted,
    old_city,
    old_district,
    old_commune_ward,
    date_hosp,
    api_address,
    longitude,
    latitude,
    new_commune_ward
  )


## Step 3: create row-stable join keys from the source labels. --------
old_area_incidence_keyed <- generate_key_dat_to_2023_v2(
  old_area_incidence_selected,
  bind_rows(
    hcmc_shapefiles$commune_312,
    hcmc_shapefiles$commune_binhduong,
    hcmc_shapefiles$commune_br_vt
  )
)

# create id for each polygon
old_area_lookup <- old_area_incidence_keyed$sf %>% mutate(
  id_space_lvl3 = row_number()
)
# add .row_id
old_area_incidence_2017_2025 <- old_area_incidence_keyed$dat %>%
  ungroup() %>%
  mutate(
    .row_id = row_number()
  )

## Step 4: Manual mapping to old area -------------
# manually assign incidence to each polygon by name
manual_mapping <- left_join(
  old_area_incidence_2017_2025,
  old_area_lookup %>%
    as_tibble() %>%
    select(-geometry),
  by = c("city_key", "district_key", "commune_key"),
  relationship = "many-to-one"
) %>%
  select(.row_id, longitude, latitude, id_space_lvl3) %>%
  rename(
    id_space_lvl3_address = id_space_lvl3
  )

## Step 5: Coordinate mapping to old area-------------
# handle cases where coordinate is right on the border between 2 polygons
# prioritize results that are consistent with the manual mapping result
coordinate_points <- manual_mapping[!is.na(manual_mapping$longitude), ]  %>%
  st_as_sf(
    coords = c("longitude", "latitude"),
    crs = st_crs("EPSG:4326"),
    remove = FALSE
  )
coordinate_hits <- st_covered_by(coordinate_points, old_area_lookup)

choose_coordinate_match <- function(containing_rows, address_id) {
  if (!length(containing_rows)) {
    return(NA_integer_)
  }
  candidate_ids <- old_area_lookup$id_space_lvl3[containing_rows]
  if (address_id %in% candidate_ids) address_id else candidate_ids[1]
}

coordinate_match_id <- map2_int(
  coordinate_hits,
  coordinate_points$id_space_lvl3_address,
  choose_coordinate_match
)

coordinate_mapping <- coordinate_points %>%
  st_drop_geometry() %>%
  ungroup() %>%
  select(.row_id) %>%
  mutate(
    id_space_lvl3_coordinate = coordinate_match_id
  )

compare_address_coordinate_mapping <- old_area_incidence_2017_2025 %>%
  # Get the polygon info from address-based mapping
  left_join(
    manual_mapping %>% select(-longitude, -latitude) %>%
      left_join(
        old_area_lookup %>%
          st_drop_geometry() %>%
          select(id_space_lvl3, name_2, name_3) %>%
          rename(address_commune = name_3, address_district = name_2),
        by = join_by(id_space_lvl3_address == id_space_lvl3)
      ),
    by = ".row_id"
  ) %>%
  # Get the polygon info from coordinate-based mapping
  left_join(
    coordinate_mapping %>%
      left_join(
        old_area_lookup %>%
          st_drop_geometry() %>%
          select(id_space_lvl3, name_2, name_3) %>%
          rename(coordinate_commune = name_3, coordinate_district = name_2),
        by = join_by(id_space_lvl3_coordinate == id_space_lvl3)
      ),
    by = ".row_id"
  ) %>%
  # select(
  #   .row_id, address_inputted, old_commune_ward, old_district, old_city,
  #   api_address, longitude, latitude,
  #   id_space_lvl3_address, id_space_lvl3_coordinate,
  #   address_commune, address_district, coordinate_commune, coordinate_district
  # ) %>%
  select(-ends_with("_key"))

## Step 6: Compute similarity index between raw address & API address -------------
# This similarity index will be used for finalizing polygon assignment in scenarios
# where address-based and coordinate based assignment don't agree

### Check similarity between raw and API addresses -----------------------------
calculate_weighted_address_similarity <- function(input_address, api_address) {
  if (is.na(input_address) || is.na(api_address)) {
    return(NA_real_)
  }

  key_input <- make_key(input_address)
  key_api <- make_key(api_address)
  if (!nzchar(key_input) || !nzchar(key_api)) {
    return(NA_real_)
  }

  # Jaro-Winkler gives higher weight to matching prefixes.
  raw_similarity <- stringsim(key_input, key_api, method = "jw", p = 0.1)
  length_weight <- log1p(nchar(key_input)) /
    log1p(max(nchar(key_input), nchar(key_api)))

  raw_similarity * length_weight
}

# Use the weighted input/API address similarity as a geocode reliability signal
# for rows where a coordinate-derived polygon would override a valid
# address-derived polygon.
dat_address_coordinate_sim <- compare_address_coordinate_mapping %>%
  mutate(
    similarity = map2_dbl(
      address_inputted,
      api_address,
      calculate_weighted_address_similarity
    )
  )

low_similarity_geocodes_old_area <- dat_address_coordinate_sim %>%
  filter(
    !is.na(similarity), id_space_lvl3_address != id_space_lvl3_coordinate,
    similarity <= quantile(similarity, .05, na.rm = TRUE)
  )

## ============ plot density
# probs <- seq(0, 1, 0.05)
# w_sim <- dat_address_coordinate_sim %>% filter(!is.na(similarity))
# if (nrow(w_sim) > 2) {
#   d <- density(w_sim %>% pull(similarity))
#
#   q_df <- tibble(
#     prob = probs,
#     similarity = quantile(.05, probs = probs, na.rm = TRUE),
#     y = approx(d$x, d$y, xout = similarity)$y
#   )
#
#   raw_api_similarity_plot <- w_sim |>
#     ggplot(aes(x = similarity)) +
#     geom_density() +
#     geom_point(
#       data = q_df,
#       aes(x = similarity, y = y),
#       color = "red",
#       size = 2
#     ) +
#     scale_x_continuous(n.breaks = 10)
#
#   print(raw_api_similarity_plot)
# }

## ======= Step 7: Compute distance for mismatched polygon assignment ==========
discrepancies_distance <- dat_address_coordinate_sim %>%
  select(.row_id, id_space_lvl3_address, id_space_lvl3_coordinate) %>%
  filter(!is.na(id_space_lvl3_address), !is.na(id_space_lvl3_coordinate)) %>%
  filter(id_space_lvl3_address != id_space_lvl3_coordinate) %>%
  left_join(
    old_area_lookup %>%
      st_transform(fm_crs_set_lengthunit(st_crs("EPSG:9210"), "km")) %>%
      select(id_space_lvl3) %>%
      rename(
        geometry_addr = geometry
      ),
    by = join_by(id_space_lvl3_address == id_space_lvl3)
  ) %>%
  left_join(
    old_area_lookup %>%
      st_transform(fm_crs_set_lengthunit(st_crs("EPSG:9210"), "km")) %>%
      select(id_space_lvl3) %>%
      rename(
        geometry_coord = geometry
      ),
    by = join_by(id_space_lvl3_coordinate == id_space_lvl3)
  ) %>%
  mutate(
    distance_km = map2_dbl(
      geometry_addr,
      geometry_coord,
      \(a, b) st_distance(a, b)
    )
  )

# merge the result back
dat_address_coordinate_sim <- dat_address_coordinate_sim %>%
  left_join(
    discrepancies_distance %>%
      st_drop_geometry() %>%
      select(.row_id, distance_km)
  )

## ======= Step 8: Map incidence to new area ==========
postreform_lookup <- hcmc_shapefiles$commune_168 %>%
  rename(
    id_space_lvl3_postreform = id_2
  )

# Build mapping by for 2 scenarios
# - exact mapping with accents
# - mapping by ascii
postreform_exact_mapping <- postreform_lookup %>%
  st_drop_geometry() %>%
  mutate(
    exact_mapping_key = str_to_lower(name_2, locale = "vi"),
    exact_mapping_key = str_replace_all(exact_mapping_key, "\\s+", "_")
  ) %>%
  select(exact_mapping_key, id_space_lvl3_postreform)

postreform_ascii_mapping<- postreform_lookup  %>%
  st_drop_geometry() %>%
  mutate(
    ascii_mapping_key = stri_trans_general(
      str_remove(name_2, "(Phường|Xã) "),
      "Latin-ASCII"
    ),
    ascii_mapping_key = make_key(ascii_mapping_key)
  ) %>%
  select(ascii_mapping_key, id_space_lvl3_postreform)  %>%
  add_count(ascii_mapping_key)  %>%
  filter(n == 1)  %>%
  select(-n)

# By this point:
# - All addresses pre-reform (hosp_date before 2025-08-01) are (guaranteed) an assignment to old commune
# - All addresses post-reform are (guaranteed) an assignment to new commune
dat_address_coordinate_sim <- dat_address_coordinate_sim %>%
  # create mapping key to get post-reform areas
  mutate(
    ascii_mapping_key = stri_trans_general(
          str_remove(new_commune_ward, "(Phường|Xã) "),
          "Latin-ASCII"
        ) %>%
      str_remove("(dao|Dac khu) "),
    ascii_mapping_key = make_key(ascii_mapping_key),
    exact_mapping_key = str_to_lower(new_commune_ward, locale="vi"),
    exact_mapping_key = str_remove(exact_mapping_key,
                                   paste0(
                                     "^(dac khu|\u0111\u1eb7c khu|xa dao|x\u00e3 \u0111\u1ea3o|",
                                     "tinh|t\u1ec9nh|phuong|ph\u01b0\u1eddng|xa|x\u00e3|",
                                     "thi tran|th\u1ecb tr\u1ea5n|thanh pho|th\u00e0nh ph\u1ed1|",
                                     "thi xa|th\u1ecb x\u00e3|huyen|huy\u1ec7n|quan|qu\u1eadn|",
                                     "tp\\.?|tx\\.?)\\s+"
                                   )),

    exact_mapping_key = str_replace_all(exact_mapping_key, "\\s+", "_")
  ) %>%
  # Try mapping by exact keys with accents first
  # THEN fall back to mapping by ascii
  # this is to avoid areas with similar/same ASCII
  left_join(postreform_exact_mapping,
            by = "exact_mapping_key",
            relationship = "many-to-one") %>%
  left_join(postreform_ascii_mapping %>%
              rename_with(~paste0(.x, "_ascii"),
                          -ascii_mapping_key),
            by = "ascii_mapping_key", relationship = "many-to-one") %>%
  mutate(
    postreform_match_method = case_when(
      !is.na(id_space_lvl3_postreform)       ~ "exact",
      !is.na(id_space_lvl3_postreform_ascii) ~ "ascii_unique",
      TRUE                                   ~ NA_character_
    ),
    id_space_lvl3_postreform = coalesce(id_space_lvl3_postreform, id_space_lvl3_postreform_ascii)
  )


# Save data for analysis ------------------
## VN projection and HCMC/global spatial extent ----------------------------
kmproj <- fm_crs_set_lengthunit(st_crs("EPSG:9210"), "km")

# Keep the crop extent in the raw lon/lat CRS because it is used to crop raw
# raster inputs before they are projected.  Use the projected sf polygon for
# plotting and mesh/model objects.
global_spatial_area_raw_crs <- old_area_lookup %>%
  select(-ends_with("_key")) %>%
  summarise(geometry = st_union(geometry), .groups = "drop")


global_spatial_area <- global_spatial_area_raw_crs %>%
  st_transform(kmproj)

extent_buffer_km <- 1
global_spatial_area_buffered_raw_crs <- global_spatial_area |>
  st_buffer(dist = extent_buffer_km)

bb <- st_bbox(global_spatial_area_buffered_raw_crs)

cropvector <- unname(as.numeric(c(
  bb["xmin"],
  bb["xmax"],
  bb["ymin"],
  bb["ymax"]
)))


# Store the durable numeric extent rather than a terra::SpatExtent; terra::crop()
# accepts this four-number vector, and it survives saveRDS() inside the data list.
hcmc_extent <- cropvector

## For postreform lookup, also check for the origin area pre-reform --------

# Get the spatial extent of HCMC, Binh Duong, BR-VT pre-reform
prereform_lvl2_boundaries <- old_area_lookup %>%
  mutate(
    postreform_origin_area = make_key(name_1),
    postreform_origin_area = case_when(
      postreform_origin_area == "tp._ho_chi_minh" ~ "hcmc_prereform",
      postreform_origin_area == "binh_duong" ~ "binh_duong_prereform",
      postreform_origin_area == "ba_ria_-_vung_tau" ~ "ba_ria_vung_tau_prereform"
    )
  )  %>%
  group_by(postreform_origin_area) %>%
  summarise(geometry = st_union(geometry)) %>%
  st_make_valid() %>%
  ungroup()

# Assign each postreform polygon to a prereform origin (i.e., HCMC, BD, or BR-VT)
postreform_origin_lookup <- postreform_lookup %>%
  select(id_space_lvl3_postreform)  %>%
  st_intersection(prereform_lvl2_boundaries %>% select(postreform_origin_area))  %>%
  mutate(overlap_area = as.numeric(st_area(geometry)))  %>%
  st_drop_geometry()  %>%
  slice_max(overlap_area, by = id_space_lvl3_postreform, n = 1, with_ties = FALSE)  %>%
  select(id_space_lvl3_postreform, postreform_origin_area)

# Join back
postreform_lookup <- postreform_lookup  %>%
  left_join(postreform_origin_lookup, by = "id_space_lvl3_postreform", relationship = "one-to-one")


## Finalize polygon assignment -----------
### Finalize pre-reform polygon assignment -----------
dat_polygon_finalized <- dat_address_coordinate_sim |>
  mutate(
    id_space_lvl3 = case_when(
      is.na(id_space_lvl3_address) ~ id_space_lvl3_coordinate,
      !is.na(distance_km) & distance_km <= 2 ~ id_space_lvl3_coordinate,
      TRUE ~ id_space_lvl3_address
    )
  )
  # select(-id_space_lvl3_coordinate, -id_space_lvl3_address)

# Sanity check
nrow(dat_polygon_finalized) == nrow(old_area_raw_incidence_2017_2025)
# id_space_lvl3 should only be NA when no lvl3 assignment can be found
sum(is.na(dat_polygon_finalized$id_space_lvl3)) == sum(
  is.na(dat_polygon_finalized$id_space_lvl3_address) & is.na(dat_polygon_finalized$id_space_lvl3_coordinate)
)

### Finalize post-reform polygon -------------
# For post-reform records only
# - compare the raw address post-reform polygon (id_space_lvl3_postreform) against the geocoded polygon
# - finalize polygon assignment based on distance
# - drop records whose pre-reform origin areas disagrees (e.g. labeled HCMC but coordinate is in BD/BR-VT).

postreform_date <- as.Date("2025-08-01")

postreform_coord_points <- dat_polygon_finalized %>%
  filter(
    date_hosp >= postreform_date,
    !is.na(longitude), !is.na(latitude)
  ) %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = raw_coordinate_crs, remove = FALSE) %>%
  st_transform(st_crs(postreform_lookup))

# get the post-reform polygon using coordinate
postreform_coord_hits <- st_covered_by(postreform_coord_points, postreform_lookup)

# this create a mapping table containing
# row_id, postreform lvl3 id based on raw addr vs coordinate
postreform_coord_mapping <- postreform_coord_points %>%
  st_drop_geometry() %>%
  select(.row_id, id_space_lvl3_postreform) %>%
  mutate(
    id_space_lvl3_postreform_coord = map_chr(
      postreform_coord_hits,
      \(hit) if (length(hit) == 1L) postreform_lookup$id_space_lvl3_postreform[hit] else NA_character_
    )
  )

# check rows with mismatched postreform lvl3 id
sum(postreform_coord_mapping$id_space_lvl3_postreform != postreform_coord_mapping$id_space_lvl3_postreform_coord, na.rm=TRUE)

# Distance between address- and coordinate-derived polygons, mismatches only
postreform_lookup_km <- postreform_lookup %>%
  st_transform(kmproj) %>%
  select(id_space_lvl3_postreform)

postreform_discrepancies_distance <- postreform_coord_mapping %>%
  filter(
    !is.na(id_space_lvl3_postreform), !is.na(id_space_lvl3_postreform_coord),
    id_space_lvl3_postreform != id_space_lvl3_postreform_coord
  ) %>%
  left_join(postreform_lookup_km %>% rename(geometry_addr = geometry),
            by = "id_space_lvl3_postreform") %>%
  left_join(postreform_lookup_km %>% rename(geometry_coord = geometry),
            by = join_by(id_space_lvl3_postreform_coord == id_space_lvl3_postreform)) %>%
  mutate(distance_km_postreform = map2_dbl(geometry_addr, geometry_coord, \(a, b) st_distance(a, b))) %>%
  st_drop_geometry() %>%
  select(.row_id, distance_km_postreform)

# Finalize: use coordinate polygon when it's <= 2km of the address polygon
postreform_final_mapping <- postreform_coord_mapping %>%
  left_join(postreform_discrepancies_distance, by = ".row_id") %>%
  mutate(
    id_space_lvl3_postreform_final = if_else(
      !is.na(distance_km_postreform) & distance_km_postreform <= 2,
      id_space_lvl3_postreform_coord,
      id_space_lvl3_postreform
    )
  ) %>%
  left_join(
    postreform_lookup %>% st_drop_geometry() %>%
      select(id_space_lvl3_postreform, final_origin = postreform_origin_area),
    by = join_by(id_space_lvl3_postreform_final == id_space_lvl3_postreform)
  ) %>%
  left_join(
    postreform_lookup %>% st_drop_geometry() %>%
      select(id_space_lvl3_postreform, coord_origin = postreform_origin_area),
    by = join_by(id_space_lvl3_postreform_coord == id_space_lvl3_postreform)
  ) %>%
  select(.row_id, id_space_lvl3_postreform_final, final_origin, coord_origin)

# Filter out records finalized as pre-reform HCMC origin while geocode is actually outside HCMC
mismatch_hcmc_only <- postreform_final_mapping %>%
  filter(final_origin == "hcmc_prereform", !is.na(coord_origin), coord_origin != "hcmc_prereform")


dat_polygon_finalized_2 <- dat_polygon_finalized %>%
  left_join(
    postreform_final_mapping %>% select(.row_id, id_space_lvl3_postreform_final),
    by = ".row_id"
  ) %>%
  mutate(id_space_lvl3_postreform = coalesce(id_space_lvl3_postreform_final, id_space_lvl3_postreform)) %>%
  select(-id_space_lvl3_postreform_final) %>%
  anti_join(mismatch_hcmc_only, by = ".row_id")

# sanity check
nrow(dat_polygon_finalized_2) == (nrow(old_area_incidence_2017_2025) - nrow(mismatch_hcmc_only))
sum(is.na(dat_polygon_finalized_2$id_space_lvl3_postreform)) == sum(
  is.na(dat_polygon_finalized_2$new_commune_ward)
)

# Final save --------------------------------------------------------------
data <- list(
  "hcmc_extent" = hcmc_extent,
  "hcmc_extent_sf" = st_as_sfc(st_bbox(
    c(
      xmin = hcmc_extent[1],
      xmax = hcmc_extent[2],
      ymin = hcmc_extent[3],
      ymax = hcmc_extent[4]
    ),
    crs = kmproj
  )),
  "kmproj" = kmproj,
  "spatial_area_lvl3_prereform" = old_area_lookup %>% st_transform(kmproj),
  "spatial_area_lvl3_postreform" = postreform_lookup %>% st_transform(kmproj),
  "vt_spatial_area_prereform" = old_area_lookup %>%  filter(name_1 == "Bà Rịa - Vũng Tàu") |> summarise(geometry = st_union(geometry)) |> st_transform(kmproj),
  "bd_spatial_area_prereform" = old_area_lookup %>%  filter(name_1 == "Bình Dương") |> summarise(geometry = st_union(geometry)) |> st_transform(kmproj),
  "hcmc_spatial_area_prereform" = old_area_lookup %>%  filter(name_1 == "TP. Hồ Chí Minh") |> summarise(geometry = st_union(geometry)) |> st_transform(kmproj),
  "global_spatial_area" = global_spatial_area,
  "incidence_data" = dat_polygon_finalized_2 %>%
    select(-id_space_lvl3_postreform_ascii, -postreform_match_method,
           -address_district, -address_commune,
           -exact_mapping_key, -ascii_mapping_key,
           -coordinate_district, -coordinate_commune)
)


saveRDS(data, "data/data_for_analysis_gisvn.RDS")
saveRDS(old_area_lookup %>%
          select(-ends_with("_key")),
        "data/lookup_area_prereform.rds")
saveRDS(postreform_lookup %>%
          select(-ends_with("_key")),
        "data/lookup_area_postreform.rds")

write_xlsx(
  dat_address_coordinate_sim %>%
    select(-.row_id, -id_space_lvl3_postreform_ascii, -postreform_match_method,
           -address_district, -address_commune,
           -exact_mapping_key, -ascii_mapping_key,
           -coordinate_district, -coordinate_commune),
  "data/incidence_2017_2025_w_sim.xlsx")

