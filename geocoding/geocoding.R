# ===== Set up ======
# install local version
# devtools::install("/Users/anhptq/Desktop/tidygeocoder")
library(tidygeocoder)
library(readxl)
library(tidyverse)
library(vietnameseConverter)


# Limit the number of geocoded address
# NOTE: Too Many Requests (RFC 6585) (HTTP 429) when LIMIT over 100
# TODO: Contact Vietmap for the request limit per minute/second
# Maybe geocode by batch of 100
LIMIT <- 100
SHEET <- "2016"

# TODO: load merged dataset (?) instead
# - Also make a wrapper func for safe file read
# --------------
CURR_YEAR <- as.numeric(SHEET)
cases_dat <- read_excel("./data/incidence/2000_2016_updated.xlsx", sheet=SHEET)
# --------------

cached_dat <- readRDS("./data/cached/geocoded_addr.rds")


# ==== Util funcs =====

# - Remove id in address
# - Resolve encoding error (for data fr 2000-2008)
# - Generate raw_addr column for geocoding
preprocess_addr <- function(data, decode_addr=FALSE){

  data %>%
    mutate(
      # sometimes addr have ID in it, remove if it's the case
      Diachi = if_else(
        !is.na(id),
        # need coalesce since if_else evaluate str_remove regardless of whether condition is met
        str_remove(Diachi, coalesce(id, " ")),
        Diachi
      ),
      # if specified, encode address from TCVN/VISCII to UTF-8 (i.e. resolve mojibake)
      Diachi = if (decode_addr) vietnameseConverter::decodeVN(Diachi, from = "TCVN3") else Diachi,
      # generate raw address to geocode
      raw_addr = paste0(
        case_when(
          !is.na(Diachi) ~ Diachi,
          !is.na(Ap) ~ Ap,
          .default = ""),
        # handle PX coded KHONG RO
        if_else(
          is.na(PX) | PX == "KHONG RO",
          "",
          paste0(", phường ", PX)
        ),
        ", quận ", QH,
        ", TP.HCM"
      )
    )
}


# ==== Get unique address ======
preprocessed_dat <- cases_dat %>%
  mutate(
    id = if_else(is.na(Maso), `Ma moi BC`, Maso)
  ) %>%
  preprocess_addr(decode_addr = CURR_YEAR<2009) %>%
  select(raw_addr) %>%
  unique()

# ====== Get addresses that are not geocoded yet ========
preprocessed_dat <- preprocessed_dat %>%
  anti_join(
    cached_dat %>% select(raw_addr),
    by = join_by(raw_addr)
  )
# preprocessed_dat

# ====== Geocode addresses ========
out <- preprocessed_dat %>%
  head(n = LIMIT) %>%
  mutate(
    geo = geo(address = raw_addr,
              method = "vietmap",
              api_options = list(
                vietmap_display_type = 2
              ),
              full_results = TRUE,
              unique_only = FALSE)
  ) %>%
  unnest(geo)

# out %>% View()

# ====== Cache output ========
# add the new output to the cached data
new_cache <- bind_rows(cached_dat,
                       out) %>%
  unique()
# new_cache

# save the data.frame of geocoded address
saveRDS(new_cache, "./data/cached/geocoded_addr.rds")

