# Packages ----------------------------------------------------------------
source("codes/00_packages.R", verbose = T)


# Shapefile ---------------------------------------------------------------
# From https://gadm.org/download_country.html
urban_unit <- read_rds("data/gadm/gadm41_VNM_3_pk.rds") %>%
  terra::unwrap() %>%
  st_as_sf(options = "ENCODING=UTF-8") %>%
  janitor::clean_names() %>%
  st_crop(
    xmin = cropvector[1],
    xmax = cropvector[2],
    ymin = cropvector[3],
    ymax = cropvector[4]
  ) %>%
  mutate(
    name_2 = ifelse(str_detect(name_1, "Minh"), name_2, "Outside HCMC"),
    name_3 = ifelse(str_detect(name_1, "Minh"), name_3, "Outside HCMC")
  ) %>%
  mutate(name_2 = stringi::stri_trans_general(name_2, "Latin-ASCII")) %>%
  mutate(name_3 = stringi::stri_trans_general(name_3, "Latin-ASCII")) %>%
  st_transform(kmproj)

# Initial CRS
crssave <- crs(urban_unit)

### Aggregating geometry at the country level
boundary_hcmc <- urban_unit %>%
  filter(name_2 != "Outside HCMC") %>%
  summarise() %>%
  st_transform(kmproj)


### Aggregating the geometry at the district level
hcmc_district <- urban_unit %>%
  group_by(name_2) %>%
  summarise() %>%
  st_transform(kmproj) |>
  mutate(id_space_district = row_number())

### Aggregating commune level
hcmc_commune <- urban_unit %>%
  group_by(name_3) %>%
  summarise() %>%
  st_transform(kmproj) |>
  mutate(id_space_commune = row_number())


### Old-school HCMC shapefiles
shapefiles_hcmc_pre_reform <- list(
  "urban_unit" = urban_unit,
  "boundary_hcmc" = boundary_hcmc,
  "hcmc_district" = hcmc_district,
  "hcmc_commune" = hcmc_commune
)

###Save
saveRDS(shapefiles_hcmc_pre_reform, "data/gadm/shapefiles_hcmc_pre_reform.RDS")
