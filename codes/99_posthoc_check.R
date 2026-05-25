source("R/gen_mapping_key.R")
library(readxl)

# --------- Load incidence data ----------
old_area_raw_incidence_2017_2025 <- bind_rows(
  map(excel_sheets("./data/incidence/incidence_2017_2025.xlsx"),
      ~ read_excel("./data/incidence/incidence_2017_2025.xlsx", sheet = .x)),
  map(excel_sheets("./data/incidence/incidence_bd_vt_2017_2025.xlsx"),
      ~ read_excel("./data/incidence/incidence_bd_vt_2017_2025.xlsx", sheet = .x))
)

# --------- Manual mapping to new commune ------
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

# ------- Summarize ---------
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
