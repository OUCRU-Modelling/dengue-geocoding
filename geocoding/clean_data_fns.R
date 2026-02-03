# Code for preprocessing data which entails
# - Ingesting data
# - Clean column names
# - Standardize address

library(readxl)
library(janitor) %>% suppressPackageStartupMessages()
library(lubridate)
library(vietnameseConverter)
library(stringi)
library(readxl)

ingest_xlsx <- function(path) {
  sheets <- excel_sheets(path)

  map(seq(1, length(sheets)), \(s_num) {
    read_excel(path, sheet = s_num) %>%
      clean_names() %>%
      suppressWarnings()
  }) %>%
    list_c()
}

clean_xlsx <- function(df, remove_accent=TRUE){
  df %>%
    mutate(
      id = if_else(is.na(maso), ma_moi_bc, maso),
      # sometimes addr have ID in it, remove if it's the case
      diachi = if_else(
        !is.na(id),
        # need coalesce since if_else evaluate str_remove regardless of whether condition is met
        str_remove(diachi, coalesce(id, " ")),
        diachi
      ),
      # for data before 2009, encode address from TCVN/VISCII to UTF-8 (i.e. resolve mojibake)
      diachi = if_else(year(ng_nhap) <= 2008, vietnameseConverter::decodeVN(diachi, from = "TCVN3"), diachi),
      diachi = if (remove_accent) stri_trans_general(diachi, id = "Latin-ASCII") else diachi,
      # generate raw address to geocode
      raw_addr = paste0(
        case_when(
          !is.na(diachi) ~ diachi,
          !is.na(ap) ~ ap,
          .default = ""),
        # handle PX coded KHONG RO or THI TRAN
        if_else(
          is.na(px) | px == "KHONG RO" | px == "THI TRAN",
          "",
          paste0(", phường ", px)
        ),
        ", quận ", qh,
        ", TP.HCM"
      ),
      raw_addr = raw_addr %>%
        str_to_title() %>%
        trimws(whitespace = "[ \t\r\n,]") %>%
        str_replace_all("\\s+", " ")
    )
}

get_clean_addr <- function(df, colname = "addr") {
  raw_addrs <- df %>%
    pull(var = colname)
  print(paste0("Number of addresses before cleaning: ", length(raw_addrs)))

  cleaned_addrs <- raw_addrs %>%
    # str_to_title() %>%
    # trimws(whitespace = "[ \t\r\n,]") %>%
    unique()
  print(paste0("Number of addresses after cleaning: ", length(cleaned_addrs)))

  cleaned_addrs
}





