# This file do the following:
# - load the dengue incidence data from 2 periods 2000-2016 and 2017-2025
# - clean and save the minimal version of the incidence data
#     (i.e., only include columns required by the LGCP model + raw_addr to map with geocoded data)
# - also create an .qs of the raw addresses to be geocoded
# Data preprocess:
# - treat diachi that are all numerics (7,954 rows) or all characters (242 rows) as NA
library(readxl)
library(tidyverse)
source("geocoding/clean_data_fns.R")

path_2000_2016 <- "./data/incidence/2000_2016_updated.xlsx"
path_2017_2025 <- "./data/incidence/DATA_FROM_HCDC/raw_data"

# ======= Process incidence data from 2000 - 2016 =========

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


# ======= Process incidence data from 2017 - 2025 =======
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


# ======= Get geocode data =======
to_geocode_2000_2016 <- incidence_2000_2016_minimal %>%
  # only include data from 2002 onwards
  # TODO: update this once weather data for 2000-2001 is available
  filter(ng_vaovien >= as.Date("2002-01-01")) %>%
  select(diachi, qh, px, raw_addr)

to_geocode_2017_2025 <- incidence_2017_2025_minimal %>%
  select(diachi, qh, px, raw_addr)

to_geocode <- bind_rows(
    to_geocode_2000_2016,
    to_geocode_2017_2025
  ) %>%
  unique()

# Check the total number of addresses to be geocoded with API
# Total for APIc: 408,418
# Total fr 2000 - 2025: 409,050
# to_geocode %>%
#   filter(!is.na(diachi)) %>%
#   {.}

# Cache to geocode df
# qs_save(to_geocode, "./data/cached/to_geocode_df.qs")


# see addresses with only numeric
# to_geocode %>%
#   filter(!is.na(diachi)) %>%
#   filter(str_detect(diachi, "^[^a-zA-Z]+$")) %>%
#   dim()

# see addresses with only characters
# to_geocode %>%
#   filter(!is.na(diachi)) %>%
#   filter(str_detect(diachi, "^[a-zA-Z]+$"))



