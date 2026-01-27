library(tidyverse)
library(tidygeocoder)
library(sf)

# create a dataframe with mixed address types
some_addresses <- tibble::tribble(
  ~name              , ~addr                                                                      ,
  "OUCRU old"        , "764 Võ Văn Kiệt, Phường 1, Quận 5, TPHCM"                                 ,
  "OUCRU new"        , "764 Vo Van Kiet, Cho Quan ward, HCMC"                                     ,
  "Marc's apartment" , "74 Nguyễn Cơ Thạch, An Lợi Đông, Thủ Đức, Thành phố Hồ Chí Minh, Vietnam"
)

# geocode the addresses
lat_longs <- some_addresses %>%
  geocode(addr, method = 'vietmap', lat = latitude, long = longitude)

# geodata::gadm("VNM", 3, path = "data")
hcmc_shp <- read_rds("data/gadm/gadm41_VNM_3_pk.rds") %>%
  terra::unwrap() %>%
  st_as_sf() %>%
  filter(GID_1 == "VNM.25_1")

ggplot() +
  geom_sf(data = hcmc_shp, aes(fill = GID_2)) +
  geom_point(data = lat_longs, aes(x = longitude, y = latitude)) +
  coord_sf(
    xlim = c(min(lat_longs$longitude) - 0.05, max(lat_longs$longitude) + 0.05),
    ylim = c(min(lat_longs$latitude) - 0.05, max(lat_longs$latitude) + 0.05),
    default_crs = sf::st_crs(4326)
  )
