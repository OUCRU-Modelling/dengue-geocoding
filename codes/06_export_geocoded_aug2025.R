source("codes/00_packages.R", verbose=TRUE)

# ======= Load incidence and geocoded addresses ======
incidence_aug2025 <- read_csv("./data/incidence/incidence_hcm_aug2025.csv")
geocoded_aug2025 <- qs_read("./data/cached/geocoded_aug2025_df.qs")


# ======= Preprocess geocoded ==============
geocoded_aug2025_clean <- geocoded_aug2025 %>%
  rename(
    vietmap_commune_id = vietmap_ward_id,
    vietmap_commune = vietmap_ward
  ) %>%
  mutate(
    new_addr_split = str_split(display_alt, "(Phường |Xã )"),
    new_commune = if_else(
      is.na(new_commune),
      map_chr(new_addr_split, \(addr){addr[length(addr)]}),
      new_commune
    ),
    new_commune_split = str_split(new_commune, ","),
    new_commune = map_chr(new_commune_split, \(addr){addr[1]}),
    new_province = if_else(
      is.na(new_province),
      map_chr(new_commune_split, \(addr){addr[2]}),
      new_province
    ),
    # get display_alt for the few addresses geocoded using previous result
    display_alt = if_else(
      is.na(display_alt),
      str_c(
        str_trim(str_c(vietmap_address, "Phường", new_commune, sep=" ")),
        new_province,
        sep=", "
      ),
      display_alt
    )
  ) %>%
  select(-new_addr_split, -new_commune_split)

# handle the 102 duplicated addr that somehow got here
geocoded_aug2025_clean <- geocoded_aug2025_clean %>%
  group_by(raw_addr) %>%
  arrange(str_length(display), .by_group = TRUE) %>%
  slice(1) %>%
  ungroup()


qs_save(geocoded_aug2025_clean, "data/cached/geocoded_aug2025_clean.qs")

# ====== Export incidence with geocode =======
# ------ For HCDC ---------
to_export_aug2025 <- incidence_aug2025 %>%
  # get quan_huyen_cu, phuong_xa_cu, thanh_pho_cu from Vietmap
  select(-thanh_pho_cu, -phuong_xa_cu, -qh) %>%
  left_join(
    geocoded_aug2025_clean %>%
      mutate(
        # get thanh_pho_cu from VietMap
        vietmap_province = str_split(display, ","),
        vietmap_province = map_chr(vietmap_province, \(split_addr){ split_addr[length(split_addr)] }),
        vietmap_province = str_trim(vietmap_province)
      ) %>%
      select(raw_addr, display_alt, long, lat, vietmap_commune, vietmap_district, vietmap_province),
    by = join_by(raw_addr == raw_addr)
  ) %>%
  rename(
    diachi_api = display_alt,
    phuong_xa_cu = vietmap_commune,
    # rename back to the OG data columns
    ngay_thang_nam_sinh = ng_sinh,
    dia_chi = diachi,
    phuong_xa_moi = px,
    quan_huyen_cu = vietmap_district,
    ngay_khoi_phat_trieu_chung = ng_khoibenh,
    ngay_nhap_vien_kham_benh = ng_vaovien,
    thanh_pho_cu = vietmap_province
  ) %>%
  arrange(ngay_nhap_vien_kham_benh) %>%
  select(-raw_addr)

writexl::write_xlsx(to_export_aug2025, "./data/geocoded_raw_inc/incidence_hcm_aug2025.xlsx")




