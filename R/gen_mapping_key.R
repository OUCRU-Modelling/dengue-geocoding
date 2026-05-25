# Function to generate key for mapping
# 1. From incidence data to 2023 VietNam shapefile (source: GISvn)
# 2. From incidence data to the old-new commune, where:
# + old commune info correspond to GISvn pre-merge shapefile
# + new commune info correspond to GISvn post-merge shapefile

# load all the changes in admin name between different timepoints:
# 2023 - time of data collection - early 2025 (before merge)
source("R/changes_in_admin_lvl3.R")
library(tidyverse)
library(stringi)

# list of hcmc shapefiles over the years
hcmc_shapefiles <- read_rds("./data/shapefiles/hcmc_shapefiles.rds")
# look up table from old commune (early 2025) -> new commune (after July 2025 merge)
old_new_map <- read_csv("data/shapefiles/px_cu_moi.csv")

make_key <- function(x) {
  x %>%
    str_trim() %>%
    stri_trans_general("Latin-ASCII") %>%
    str_to_lower() %>%
    str_replace_all("\\s+", "_")
}

generate_key_dat_to_2023 <- function(data,
                                     gis=hcmc_shapefiles$commune_312){
  newdat <- data %>%
    mutate(
      city_key     = make_key(thanh_pho_cu),
      city_key     = recode(city_key, "tp._h.c.m"="tp._ho_chi_minh"),
      city_key     = str_remove(city_key, "^tinh_"),
      district_key = make_key(quan_huyen_cu),
      district_key = str_remove(district_key, "^(quan_|huyen_|thanh_pho_)"),
      commune_key  = make_key(phuong_xa_cu),
      commune_key = str_remove(commune_key, "^(phuong_|xa_|thi_tran_)")
    ) %>%
    group_by(commune_key, district_key, city_key) %>%
    # ------ handle changes in district/commune between data & 2023 GIS sf --------
  left_join(commune_district_crosswalk_2023,
            by = c("city_key", "district_key", "commune_key"),
            relationship = "many-to-one") %>%
    mutate(
      district_key = coalesce(shapefile_district_key, district_key),
      commune_key = coalesce(shapefile_commune_key, commune_key)
    )

  newgis <- gis %>%
    mutate(
      city_key     = make_key(name_1),
      district_key = make_key(name_2),
      commune_key  = make_key(name_3)
    ) %>%
    hcmc_shapefiles$merge_polygon(
      merge_map = merge_gis_polygons,
      colname = "commune_key"
    ) %>%
    # special handling for tam_an
    mutate(
      city_key = if_else(commune_key == "tam_an",
                         "ba_ria_-_vung_tau",
                         city_key),
      district_key = if_else(commune_key == "tam_an",
                             "long_dat",
                             district_key)
    )

  list(
    dat = newdat,
    sf = newgis
  )
}


generate_key_dat_to_2025 <- function(data,
                                     old_new_map){
  newdat <- data %>%
    mutate(
      city_key     = make_key(thanh_pho_cu),
      city_key     = recode(city_key, "tp._h.c.m"="tp._ho_chi_minh"),
      city_key     = str_remove(city_key, "^tinh_"),
      district_key = make_key(quan_huyen_cu),
      district_key = str_remove(district_key, "^(quan_|huyen_|thanh_pho_)"),
      commune_key  = make_key(phuong_xa_cu),
      commune_key = str_remove(commune_key, "^(phuong_|xa_|thi_tran_)")
    ) %>%
    group_by(commune_key, district_key, city_key) %>%
    # ------ step 1: map data district/commune to 2023 GIS sf key --------
  left_join(commune_district_crosswalk_2023,
            by = c("city_key", "district_key", "commune_key"),
            relationship = "many-to-one") %>%
    mutate(
      district_key = coalesce(shapefile_district_key, district_key),
      commune_key = coalesce(shapefile_commune_key, commune_key)
    ) %>%
    # ------ step 2: map data from 2023 key to 2025 GIS sf key -------
  left_join(commune_district_crosswalk_2023_2025,
            by = c("city_key", "district_key", "commune_key"),
            relationship = "many-to-one") %>%
    mutate(
      district_key = coalesce(new_district_key, district_key),
      commune_key = coalesce(new_commune_key, commune_key)
    )

  list(
    dat = newdat,
    mapping = old_new_map %>%
      mutate(
        commune_key  = make_key(ten_xa_cu),
        district_key = make_key(ten_huyen_cu),
        city_key     = make_key(ten_tinh_cu)
      )
  )
}
