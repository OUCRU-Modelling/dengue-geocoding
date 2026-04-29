# Export geocoded dengue incidence by hospitalization year
source("codes/00_packages.R", verbose=TRUE)

# ======= Load incidence and geocoded addresses ======
incidence_bd_vt <- read_csv("./data/incidence/incidence_bd_vt_2017_2025.csv")
geocoded_addr_bd_vt <- qs_read("./data/cached/geocoded_bd_vt_df.qs")

# preprocess new address
geocoded_addr_bd_vt_clean <- geocoded_addr_bd_vt %>%
  mutate(
    new_addr_split = str_split(display_alt, "(Phường |Xã )"),
    new_commune = map_chr(new_addr_split, \(addr){addr[length(addr)]}),
    new_commune_split = str_split(new_commune, ","),
    new_commune = map_chr(new_commune_split, \(addr){addr[1]}),
    new_province = map_chr(new_commune_split, \(addr){addr[2]})
  ) %>%
  select(-new_addr_split, -new_commune_split)

# ========== Export data ===========
to_export_bd_vt <- incidence_bd_vt %>%
  left_join(
    geocoded_addr_bd_vt_clean %>%
      select(raw_addr, display, long, lat, new_commune)
  )

# ----------- For HCDC -------------
to_export_bd_vt_list <- to_export_bd_vt %>%
  rename(
    diachi_api = display,
    px_moi = new_commune,
    # rename back to the OG data columns
    ngay_thang_nam_sinh = ng_sinh,
    dia_chi = diachi,
    phuong_xa_cu = px,
    quan_huyen_cu = qh,
    ngay_khoi_phat_trieu_chung = ng_khoibenh,
    ngay_nhap_vien_kham_benh = ng_vaovien
  ) %>%
  mutate(
    year_hosp = year(ngay_nhap_vien_kham_benh)
  ) %>%
  group_by(year_hosp) %>%
  nest()

# Export as a xlsx file
map2(to_export_bd_vt_list$year_hosp, to_export_bd_vt_list$data, \(year, dat){
    # drop columns all NA
    dat %>%
      select(where(~ !all(is.na(.)))) %>%
      select(-raw_addr)
  }) %>%
  set_names(unique(to_export_bd_vt_list$year_hosp)) %>%
  writexl::write_xlsx("./data/geocoded_raw_inc/incidence_bd_vt_2017_2025.xlsx")

# ----------- For Modelling -------------
to_export_bd_vt_model <- to_export_bd_vt %>%
  select(
    ng_vaovien, long, lat
  ) %>%
  rename(
    date_hosp = ng_vaovien,
    long = long,
    lat = lat
  ) %>%
  mutate(
    year_hosp = year(date_hosp)
  ) %>%
  group_by(year_hosp) %>%
  nest()

to_export_bd_vt %>%
  rename(
    date_hosp = ng_vaovien,
    long = long,
    lat = lat
  ) %>%
  mutate(
    year_hosp = year(date_hosp)
  ) %>%
  group_by(thanh_pho_cu, year_hosp) %>%
  summarize(
    total_inc = n(),
    na_inc = sum(is.na(diachi)),
    geocoded_inc = sum(!is.na(long)),
    geo_prop = geocoded_inc/(total_inc - na_inc)
  ) %>%
  arrange(thanh_pho_cu, year_hosp) %>%
  View()

map2(to_export_bd_vt_model$data, to_export_bd_vt_model$year_hosp, \(dat, year){
  dat %>%
    filter(!is.na(long), !is.na(lat)) %>%
    st_as_sf(
      coords = c("long", "lat"),
      crs    = 4326
    ) %>%
    saveRDS(paste0("./data/geocoded_data/bd_vt/geocoded_bd_vt_", year, ".rds"))
})


