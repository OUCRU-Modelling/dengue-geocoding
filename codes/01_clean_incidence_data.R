# This file do the following:
# - load the dengue incidence data from 2 periods 2000-2016 and 2017-2025
# - clean and save the minimal version of the incidence data
#     (i.e., only include columns required by the LGCP model + raw_addr to map with geocoded data)
# Data preprocess:
# - treat diachi that are all numerics (7,954 rows) or all characters (242 rows) as NA

# ======== Packages ========================================
source("codes/00_packages.R", verbose = T)
source("R/clean_data_fns.R")

path_2000_2016 <- "./data/incidence/DATA_FROM_HCDC/cleaned_data/2000_2016_updated.xlsx"
path_2017_2025 <- "./data/incidence/DATA_FROM_HCDC/raw_data"
path_aug2025 <- "./data/incidence/DATA_FROM_HCDC/cleaned_data/sxh_3KV_T8_2025_T12_2025_for_use.xlsx"

# ======= Process HCMC incidence data from 2000 - 2016 =========

# -------- Get/generate minimal incidence data 2000 - 2016
incidence_2000_2016_minimal <- if(!file.exists("./data/incidence/incidence_2000_2016_minimal.csv")){

  incidence_2000_2016 <- ingest_xlsx(path_2000_2016) %>%
    clean_xlsx(remove_accent = TRUE, prefix = TRUE, all_chr_na=TRUE, all_num_na = TRUE)

  minimal_2000_2016 <- incidence_2000_2016 %>%
    arrange(ng_vaovien) %>%
    select(
      maso, tuoi, diachi, px, qh, raw_addr, ng_khoibenh, ng_vaovien
    )

  write_csv(minimal_2000_2016, "./data/incidence/incidence_2000_2016_minimal.csv")

  minimal_2000_2016
}else{
  read_csv("./data/incidence/incidence_2000_2016_minimal.csv")
}


# ======= Process HCMC incidence data from 2017 - 2025 =======
# -------- Get/generate minimal incidence data 2017 - 2025
incidence_2017_2025_minimal <- if(!file.exists("./data/incidence/incidence_2017_2025_minimal.csv")){
  files <- list.files(path_2017_2025, full.names = TRUE)
  files <- files[str_detect(files, "HCM")] # exclude Vung Tau and Binh Duong

  # load all the raw files
  incidence_2017_2025 <- map(
    files,
    \(file){
      ingest_xlsx(file)
    }
  ) %>%
    bind_rows()

  minimal_2017_2025 <- incidence_2017_2025 %>%
    # make it a little bit more consistent with the old data
    rename(
      ng_sinh = ngay_thang_nam_sinh,
      diachi = dia_chi,
      px = phuong_xa_cu,
      qh = quan_huyen_cu,
      ng_khoibenh = ngay_khoi_phat_trieu_chung,
      ng_vaovien = ngay_nhap_vien_kham_benh
    ) %>%
    select(
      tuoi, diachi, px, qh, ng_khoibenh, ng_vaovien
    ) %>%
    arrange(ng_vaovien) %>%
    clean_xlsx(remove_accent = TRUE, prefix=FALSE, all_chr_na=TRUE, all_num_na = TRUE)

  write_csv(minimal_2017_2025, "./data/incidence/incidence_2017_2025_minimal.csv")

  minimal_2017_2025
} else{
  read_csv("./data/incidence/incidence_2017_2025_minimal.csv")
}

# ======= Process BD - VT data from 2017 - 2025 =======
# Note that the output format is slightly different since this data is not used for modelling
incidence_bd_vt_2017_2025 <- if(!file.exists("./data/incidence/incidence_bd_vt_2017_2025.csv")){
  files <- list.files("./data/incidence/DATA_FROM_HCDC/cleaned_data", full.names = TRUE)
  files <- files[str_detect(files, "bd|vt")] # get Vung Tau and Binh Duong

  # load all the raw files
  incidence_bd_vt_2017_2025 <- map(
    files,
    \(file){
      ingest_xlsx(file)
    }
  ) %>%
    bind_rows()

  clean_bd_vt_2017_2025 <- incidence_bd_vt_2017_2025 %>%
    # make it a little bit more consistent with the old data
    rename(
      ng_sinh = ngay_thang_nam_sinh,
      diachi = dia_chi,
      px = phuong_xa_cu,
      qh = quan_huyen_cu,
      ng_khoibenh = ngay_khoi_phat_trieu_chung,
      ng_vaovien = ngay_nhap_vien_kham_benh
    ) %>%
    arrange(ng_vaovien) %>%
    clean_xlsx(remove_accent = TRUE, prefix=FALSE, all_chr_na=TRUE, all_num_na = TRUE)

  write_csv(clean_bd_vt_2017_2025, "./data/incidence/incidence_bd_vt_2017_2025.csv")

  clean_bd_vt_2017_2025
} else{
  read_csv("./data/incidence/incidence_bd_vt_2017_2025.csv")
}


# ======= Process HCMC data post 2025 merge =======
incidence_hcm_aug2025 <- if(!file.exists("./data/incidence/incidence_hcm_aug2025.csv")){
  # load the raw incidence data
  incidence_hcm_aug2025 <- ingest_xlsx(path_aug2025)

  clean_hcm_aug2025 <- incidence_hcm_aug2025 %>%
    # make it a little bit more consistent with the old data
    rename(
      ng_sinh = ngay_thang_nam_sinh,
      diachi = dia_chi,
      px = phuong_xa_moi,
      qh = quan_huyen_cu,
      ng_khoibenh = ngay_khoi_phat_trieu_chung,
      ng_vaovien = ngay_nhap_vien_kham_benh
    ) %>%
    arrange(ng_vaovien) %>%
    clean_xlsx(remove_accent = TRUE, prefix=FALSE, all_chr_na=TRUE, all_num_na = TRUE)

  write_csv(clean_hcm_aug2025, "./data/incidence/incidence_hcm_aug2025.csv")

  clean_hcm_aug2025
} else{
  read_csv("./data/incidence/incidence_hcm_aug2025.csv")
}

