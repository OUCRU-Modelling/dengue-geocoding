# Preprocess the geocoded_addr data.frame
# - Update the new commune post 2025 reform
# - Remove geocodes that are outside of HCMC
source("codes/00_packages.R", verbose=TRUE)
source("R/gisvn_api.R")

geocoded_addr <- qs_read("data/cached/geocoded_addr.qs")

# -------- Preprocess geocoded addresses ---------
# minor refactoring for clarity
geocoded_addr <- geocoded_addr %>%
  rename(
    vietmap_commune_id = vietmap_ward_id,
    vietmap_commune = vietmap_ward
  ) %>%
  mutate(
    # extract province of vietmap output
    display_split = str_split(display, ","),
    vietmap_province = map_chr(display_split, \(addr){str_trim(addr[length(addr)])})
  ) %>%
  select(-display_split)

# If new addresses fr VietMap available --> use that address
# If NA --> get the new address using gis.vn API
vietmap_new_addr <- geocoded_addr %>%
  filter(!is.na(display_alt)) %>%
  mutate(
    new_addr_split = str_split(display_alt, "(Phường |Xã )"),
    new_commune = map_chr(new_addr_split, \(addr){addr[length(addr)]}),
    new_commune_split = str_split(new_commune, ","),
    new_commune = map_chr(new_commune_split, \(addr){addr[1]}),
    new_province = map_chr(new_commune_split, \(addr){addr[2]})
  ) %>%
  select(-new_addr_split, -new_commune_split)

gis_new_addr <- geocoded_addr %>%
  filter(is.na(display_alt)) %>%
  mutate(
    new_addr = map2(lat, long, \(lat, long){
      get_new_addr(lat=lat, lng=long)
    })
  ) %>%
  unnest_wider(new_addr)

# update label for consistency
gis_new_addr <- gis_new_addr %>%
  mutate(
    new_province = if_else(
      new_province == "TP. Hồ Chí Minh", "Thành Phố Hồ Chí Minh", new_province
    )
  )

# -------- Get clean geocoded addr ---------
geocoded_addr_clean <- bind_rows(
    gis_new_addr,
    vietmap_new_addr
  ) %>%
  filter(
    vietmap_province == "Thành Phố Hồ Chí Minh"
  ) %>%
  select(
    # remove redundant column
    - display_alt
  )

qs_save(geocoded_addr_clean, "./data/cached/geocoded_addr_clean.qs")


