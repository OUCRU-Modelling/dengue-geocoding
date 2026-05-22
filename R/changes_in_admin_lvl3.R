# Changes in commune level from data to 2023 (time of GISvn shape file)
commune_district_crosswalk_2023 <- tribble(
  ~city_key,          ~district_key,  ~commune_key,      ~shapefile_district_key,  ~shapefile_commune_key,
  "ba_ria_-_vung_tau", "long_dat",    "dat_do",          "dat_do",                 "dat_do",
  "ba_ria_-_vung_tau", "long_dat",    "lang_dai",        "dat_do",                 "lang_dai",
  "ba_ria_-_vung_tau", "long_dat",    "long_tan",        "dat_do",                 "long_tan",
  "ba_ria_-_vung_tau", "long_dat",    "phuoc_hai",       "dat_do",                 "phuoc_hai",
  "ba_ria_-_vung_tau", "long_dat",    "phuoc_hoi",       "dat_do",                 "phuoc_hoi",
  "ba_ria_-_vung_tau", "long_dat",    "phuoc_long_tho",  "dat_do",                 "phuoc_long_tho",
  "ba_ria_-_vung_tau", "long_dat",    "long_hai",        "long_dien",              "long_hai",
  "ba_ria_-_vung_tau", "long_dat",    "long_dien",       "long_dien",              "long_dien",
  "ba_ria_-_vung_tau", "long_dat",    "phuoc_hung",      "long_dien",              "phuoc_hung",
  "ba_ria_-_vung_tau", "long_dat",    "phuoc_tinh",      "long_dien",              "phuoc_tinh",
  # establish Thu Duc city
  "tp._ho_chi_minh",  "2",           "an_loi_dong",     "thu_duc",                "an_loi_dong",
  "tp._ho_chi_minh",  "2",           "an_phu",          "thu_duc",                "an_phu",
  "tp._ho_chi_minh",  "2",           "binh_an",         "thu_duc",                "an_khanh", # changes in 2021
  "tp._ho_chi_minh",  "2",           "binh_trung_dong", "thu_duc",                "binh_trung_dong",
  "tp._ho_chi_minh",  "2",           "binh_trung_tay",  "thu_duc",                "binh_trung_tay",
  "tp._ho_chi_minh",  "2",           "cat_lai",         "thu_duc",                "cat_lai",
  "tp._ho_chi_minh",  "2",           "thanh_my_loi",    "thu_duc",                "thanh_my_loi",
  "tp._ho_chi_minh",  "2",           "thao_dien",       "thu_duc",                "thao_dien",
  "tp._ho_chi_minh",  "2",           "thu_thiem",       "thu_duc",                "thu_thiem",
  "tp._ho_chi_minh",  "9",           "hiep_phu",        "thu_duc",                "hiep_phu",
  "tp._ho_chi_minh",  "9",           "long_binh",       "thu_duc",                "long_binh",
  "tp._ho_chi_minh",  "9",           "long_phuoc",      "thu_duc",                "long_phuoc",
  "tp._ho_chi_minh",  "9",           "long_thanh_my",   "thu_duc",                "long_thanh_my",
  "tp._ho_chi_minh",  "9",           "long_truong",     "thu_duc",                "long_truong",
  "tp._ho_chi_minh",  "9",           "phu_huu",         "thu_duc",                "phu_huu",
  "tp._ho_chi_minh",  "9",           "phuoc_binh",      "thu_duc",                "phuoc_binh",
  "tp._ho_chi_minh",  "9",           "phuoc_long_a",    "thu_duc",                "phuoc_long_a",
  "tp._ho_chi_minh",  "9",           "phuoc_long_b",    "thu_duc",                "phuoc_long_b",
  "tp._ho_chi_minh",  "9",           "tan_phu",         "thu_duc",                "tan_phu",
  "tp._ho_chi_minh",  "9",           "tang_nhon_phu_a", "thu_duc",                "tang_nhon_phu_a",
  "tp._ho_chi_minh",  "9",           "tang_nhon_phu_b", "thu_duc",                "tang_nhon_phu_b",
  "tp._ho_chi_minh",  "9",           "truong_thanh",    "thu_duc",                "truong_thanh",
  # Changes in Thu Duc commune
  # changes in D3
  # https://hcmcpv.org.vn/tin-tuc/thanh-lap-phuong-vo-thi-sau-quan-3-tphcm-1491873274
  "tp._ho_chi_minh",  "3",           "6",               "3",                      "vo_thi_sau",
  # "ba_ria_-_vung_tau",  "ba_ria",   "phuoc_hiep",  "ba_ria",   "phuoc_trung",
)

# In cases where data have merged commune --> merge shapefile instead
merge_gis_polygons <- list(
  "tam_an" = c("an_ngai", "tam_nhut", "tam_phuoc"),
  "phuoc_trung" = c("phuoc_trung", "phuoc_hiep"),
  "phuoc_hoi" = c("phuoc_hoi", "loc_an"),
  "phuoc_hai" = c("phuoc_hai", "long_my")
)

# merge_gis_polygons <- tribble(
#   ~city_key,          ~district_key,  ~commune_key,      ~new_district_key,  ~new_commune_key,
#   # district rename only — commune name unchanged, just remap district key
#   "ba_ria_-_vung_tau",  "long_dien", "an_ngai",     "long_dat",  "tam_an",
#   "ba_ria_-_vung_tau",  "long_dien", "an_nhut",     "long_dat",  "tam_an",
#   "ba_ria_-_vung_tau",  "long_dien", "tam_phuoc",   "long_dat",  "tam_an",
#   # Changes in ba ria vung tau
#   # NQ 1256, effective 1/1/2025 — these dissolve into new units
#   "ba_ria_-_vung_tau",  "ba_ria",   "phuoc_hiep",  "ba_ria",   "phuoc_trung",
#   "ba_ria_-_vung_tau",  "dat_do",   "loc_an",      "long_dat", "phuoc_hoi",
#   "ba_ria_-_vung_tau",  "dat_do",   "long_my",     "long_dat", "phuoc_hai",
# )


# Changes in commune level from 2023 to early 2025 (before merge)
commune_district_crosswalk_2023_2025 <- tribble(
  ~city_key,          ~district_key,  ~commune_key,      ~new_district_key,  ~new_commune_key,
  # mapping changes from 2023 2025
  # https://luatvietnam.vn/tin-van-ban-moi/sap-xep-dvhc-cap-xa-10-quan-cua-tp-hcm-giai-doan-2023-2025-186-100018-article.html
  "tp._ho_chi_minh",  "3",           "10",               "3",                      "9",
  "tp._ho_chi_minh",  "3",           "13",               "3",                      "12",
  # Q4: P6→P9, P10→P8, P14→P15
  "tp._ho_chi_minh",  "4",           "6",   "4",           "9",
  "tp._ho_chi_minh",  "4",           "10",  "4",           "8",
  "tp._ho_chi_minh",  "4",           "14",  "4",           "15",
  # Q5: P3→P2, P6→P5, P8→P7, P10→P11
  "tp._ho_chi_minh",  "5",           "3",   "5",           "2",
  "tp._ho_chi_minh",  "5",           "6",   "5",           "5",
  "tp._ho_chi_minh",  "5",           "8",   "5",           "7",
  "tp._ho_chi_minh",  "5",           "10",  "5",           "11",
  # Q6: P3+P4→P1, P6+(part P5)→P2, (rest P5)→P9, (part P10)→P11, (part P13)→P14
  "tp._ho_chi_minh",  "6",           "4",   "6",           "1",
  "tp._ho_chi_minh",  "6",           "6",   "6",           "2",
  "tp._ho_chi_minh",  "6",           "5",   "6",           "2",   # part P5 goes to P2 and P9
  "tp._ho_chi_minh",  "6",           "3",   "6",           "1",   # P3→P1
  # Q8: P1+P2+P3→rach_ong, P8+P9+P10→hung_phu, P11+P12+P13→xom_cui
  "tp._ho_chi_minh",  "8",           "1",   "8",           "rach_ong",
  "tp._ho_chi_minh",  "8",           "2",   "8",           "rach_ong",
  "tp._ho_chi_minh",  "8",           "3",   "8",           "rach_ong",
  "tp._ho_chi_minh",  "8",           "8",   "8",           "hung_phu",
  "tp._ho_chi_minh",  "8",           "9",   "8",           "hung_phu",
  "tp._ho_chi_minh",  "8",           "10",  "8",           "hung_phu",
  "tp._ho_chi_minh",  "8",           "11",  "8",           "xom_cui",
  "tp._ho_chi_minh",  "8",           "12",  "8",           "xom_cui",
  "tp._ho_chi_minh",  "8",           "13",  "8",           "xom_cui",
  # Q10: P10+P11→P10, P5+P8→P8, P7+P6→P6
  "tp._ho_chi_minh",  "10",          "11",              "10",                     "10",
  "tp._ho_chi_minh",  "10",          "5",               "10",                     "8",
  "tp._ho_chi_minh",  "10",          "7",               "10",                     "6",
  # Q11: P2→P1, P4+P6→P7, P12→P8, P9→P10, P13→P11
  "tp._ho_chi_minh",  "11",          "2",   "11",          "1",
  "tp._ho_chi_minh",  "11",          "4",   "11",          "7",
  "tp._ho_chi_minh",  "11",          "6",   "11",          "7",
  "tp._ho_chi_minh",  "11",          "9",   "11",          "10",
  "tp._ho_chi_minh",  "11",          "12",  "11",          "8",
  "tp._ho_chi_minh",  "11",          "13",  "11",          "11",
  # Binh Thanh: P3→P1, P15→P2, P21→P19, P24→P14, (part P6)→P5, (rest P6)→P7, (part P13)→P11
  "tp._ho_chi_minh",  "binh_thanh",  "3",   "binh_thanh",  "1",
  "tp._ho_chi_minh",  "binh_thanh",  "15",  "binh_thanh",  "2",
  "tp._ho_chi_minh",  "binh_thanh",  "21",  "binh_thanh",  "19",
  "tp._ho_chi_minh",  "binh_thanh",  "24",  "binh_thanh",  "14",
  "tp._ho_chi_minh",  "binh_thanh",  "6",   "binh_thanh",  "5",
  # Go Vap: P4+P7→P1, P9→P8, P13→P15 (with part→P14)
  "tp._ho_chi_minh",  "go_vap",      "4",   "go_vap",      "1",
  "tp._ho_chi_minh",  "go_vap",      "7",   "go_vap",      "1",
  "tp._ho_chi_minh",  "go_vap",      "9",   "go_vap",      "8",
  "tp._ho_chi_minh",  "go_vap",      "13",  "go_vap",      "15",
  # Phu Nhuan: P3→P4, P17→P15
  "tp._ho_chi_minh",  "phu_nhuan",   "3",   "phu_nhuan",   "4",
  "tp._ho_chi_minh",  "phu_nhuan",   "17",  "phu_nhuan",   "15",
  # Binh Chanh: qui_duc → hung_long
  "tp._ho_chi_minh",  "binh_chanh",  "qui_duc",  "binh_chanh", "hung_long",
  # Ba Ria - Vung Tau
  "ba_ria_-_vung_tau",  "ba_ria",    "phuoc_hiep",  "ba_ria",    "phuoc_trung",
  "ba_ria_-_vung_tau",  "long_dat",  "long_my",     "long_dat",  "phuoc_hai",
  "ba_ria_-_vung_tau",  "long_dat",  "loc_an",      "long_dat",  "phuoc_hoi",
  # district rename only — commune name unchanged, just remap district key
  "ba_ria_-_vung_tau",  "long_dien", "an_ngai",     "long_dat",  "an_ngai",
  "ba_ria_-_vung_tau",  "long_dien", "an_nhut",     "long_dat",  "an_nhut",
  "ba_ria_-_vung_tau",  "long_dien", "tam_phuoc",   "long_dat",  "tam_phuoc",
  # Changes in ba ria vung tau
  # NQ 1256, effective 1/1/2025 — these dissolve into new units
  "ba_ria_-_vung_tau",  "ba_ria",   "phuoc_hiep",  "ba_ria",   "phuoc_trung",
  "ba_ria_-_vung_tau",  "dat_do",   "loc_an",      "long_dat", "phuoc_hoi",
  "ba_ria_-_vung_tau",  "dat_do",   "long_my",     "long_dat", "phuoc_hai",
)
