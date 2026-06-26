# Generate HCMC data after the 2025 merge to be geocoded
# Do the following:
# - Load the incidence data and filter valid addresses
# - Cross check with geocoded dataset (from before merging) for addresses that have been geocoded before
source("codes/00_packages.R", verbose=TRUE)

incidence_hcm_aug2025 <- read_csv("./data/incidence/incidence_hcm_aug2025.csv")

# ======== Get data to be geocoded =============
to_geocode_aug2025 <- incidence_hcm_aug2025 %>%
  arrange(ng_vaovien) %>%
  mutate(
    # enforce stricter condition, consider addresses as missing when:
    # - diachi contains all alphabet characters/space
    # - diachi contains all numeric/space
    diachi = case_when(
      str_detect(diachi, "^[a-zA-Z [:punct:]]+$") ~ NA,
      str_detect(diachi, "^[^a-zA-Z [:punct:]]+$") ~ NA,
      .default = diachi
    )
  ) %>%
  filter(
    !is.na(diachi),
    # only geocode diachi with at least 3 characters
    str_length(diachi)>3,
    # only geocode diachi with at least 2 consecutive alphabet characters
    str_detect(diachi, "[A-Za-z][A-Za-z]+")
  ) %>%
  select(diachi, px, raw_addr) %>%
  unique()

qs_save(to_geocode_aug2025, "data/cached/to_geocode_aug2025.qs")

# ============= Check for data that have been geocoded before ================
geocoded_df <- qs_read("data/cached/geocoded_addr_clean.qs")
geocoded_bd_vt_df <- qs_read("data/cached/geocoded_bd_vt_clean.qs")

geocoded_b4_merge <- bind_rows(
    geocoded_df,
    geocoded_bd_vt_df
  ) %>%
  mutate(
    diachi = str_split(raw_addr, ","),
    diachi = map_chr(diachi, \(str){str[1]})
  ) %>%
  rename(
    # need to rename here to ensure the data match the one returned by tidygeocoder
    vietmap_ward_id = vietmap_commune_id,
    vietmap_ward = vietmap_commune
  ) %>%
  select(-raw_addr)

# populate the geocoded addresses so we dont have to geocode the same address again
geocoded_aug2025 <- to_geocode_aug2025 %>%
  mutate(
    # generate key to map to geocoded address
    px_key = str_remove(px, "(Phường |Xã)"),
    px_key = case_when(
      # str_detect(px, "^0\\d$") ~ str_replace(px, "0", "Phường "),
      str_detect(px_key, "^\\d+$") ~ paste0("Phường ", px_key),
      .default = px_key
    )
  ) %>%
  left_join(
    geocoded_b4_merge,
    by = join_by(diachi == diachi, px_key == new_commune)
  ) %>%
  unique() %>%
  filter(!is.na(long)) %>%
  rename(
    new_commune = px_key
  ) %>%
  # make this more consistent with the format that will be returned by the API
  select(raw_addr, lat, long, display, vietmap_address, vietmap_district_id,
         vietmap_district, vietmap_ward_id, vietmap_ward, new_commune, new_province)

# qs_save(geocoded_aug2025, "data/cached/geocoded_aug2025_df.qs")
to_geocode_aug2025

