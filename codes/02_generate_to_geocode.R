# Generate the to_geocode_df.qs file containing all raw addresses to be geocoded
source("codes/00_packages.R", verbose=TRUE)

incidence_2000_2016_minimal <- read_csv("./data/incidence/incidence_2000_2016_minimal.csv")
incidence_2017_2025_minimal <- read_csv("./data/incidence/incidence_2017_2025_minimal.csv")

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

# qs_save(to_geocode, "./data/cached/to_geocode_df.qs")
to_geocode
