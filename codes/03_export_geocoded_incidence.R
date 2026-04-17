# Export geocoded dengue incidence by hospitalization year
source("codes/00_packages.R", verbose=TRUE)

# ======= Load incidence and geocoded addresses ======
incidence_2000_2016_minimal <- read_csv("./data/incidence/incidence_2000_2016_minimal.csv")
incidence_2017_2025_minimal <- read_csv("./data/incidence/incidence_2017_2025_minimal.csv")
full_incidence <- bind_rows(
  incidence_2000_2016_minimal,
  incidence_2017_2025_minimal
)
geocoded_addr <- qs_read("./data/cached/geocoded_addr.qs")


# ========== Export data ===========
start_date <- "2002-01-01"
end_date <- "2022-01-01"
to_export <- full_incidence %>%
  left_join(
    geocoded_addr %>% select(raw_addr, long, lat)
  ) %>%
  filter(
    ng_vaovien >= as.Date(start_date),
    ng_vaovien < as.Date(end_date)
  )

to_export_list <- to_export %>%
  select(
    maso, ng_vaovien, long, lat
  ) %>%
  rename(
    patient_id = maso,
    date_hosp = ng_vaovien,
    long = long,
    lat = lat
  ) %>%
  mutate(
    year_hosp = year(date_hosp)
  ) %>%
  group_by(year_hosp) %>%
  nest()

# Export by year of hospitalization
map2(to_export_list$data, to_export_list$year_hosp, \(dat, year){
  dat %>%
    filter(!is.na(long), !is.na(lat)) %>%
    st_as_sf(
      coords = c("long", "lat"),
      crs    = 4326
    ) %>%
    saveRDS(paste0("./data/geocoded_data/geocoded_", year, ".rds"))
})
