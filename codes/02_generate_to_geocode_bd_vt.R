# Generate the to_geocode_df.qs file containing all raw addresses to be geocoded
source("codes/00_packages.R", verbose=TRUE)

incidence_bd_vt_2017_2025 <- read_csv("./data/incidence/incidence_bd_vt_2017_2025.csv")

# ======= Get geocode data =======
to_geocode_bd_vt_2017_2025 <- incidence_bd_vt_2017_2025 %>%
  select(diachi, qh, px, raw_addr) %>%
  unique()

to_geocode_bd_vt <- to_geocode_bd_vt_2017_2025 %>%
  mutate(
    # enforce stricter condition, consider addresses as missing when:
    # - diachi contains all alphabet characters/space
    # - diachi contains all numeric/space
    diachi = case_when(
      str_detect(diachi, "^[a-zA-Z ]+$") ~ NA,
      str_detect(diachi, "^[^a-zA-Z ]+$") ~ NA,
      .default = diachi
    )
  ) %>%
  filter(
    !is.na(diachi),
    # only geocode diachi with at least 3 characters
    str_length(diachi)>3,
    # only geocode diachi with at least 2 consecutive alphabet characters
    str_detect(diachi, "[A-Za-z][A-Za-z]+")
  )

dim(to_geocode_bd_vt)

# qs_save(to_geocode_bd_vt, "./data/cached/to_geocode_bd_vt_df.qs")
to_geocode_bd_vt
