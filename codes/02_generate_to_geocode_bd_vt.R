# Generate the to_geocode_df.qs file containing all raw addresses to be geocoded
source("codes/00_packages.R", verbose=TRUE)

incidence_bd_vt_2017_2025 <- read_csv("./data/incidence/incidence_bd_vt_2017_2025.csv")

# ======= Get geocode data =======
to_geocode_bd_vt_2017_2025 <- incidence_bd_vt_2017_2025 %>%
  select(diachi, qh, px, raw_addr) %>%
  unique()

to_geocode_bd_vt <- to_geocode_bd_vt_2017_2025 %>%
  filter(
    !is.na(diachi),
    # only geocode diachi with at least 3 characters
    str_length(diachi)>3
  )

dim(to_geocode_bd_vt)

# qs_save(to_geocode_bd_vt, "./data/cached/to_geocode_bd_vt_df.qs")
to_geocode_bd_vt
