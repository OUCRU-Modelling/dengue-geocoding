# Compare the distance between raw address vs API assigned address
source("codes/00_packages.R", verbose=TRUE)
library(readxl)

# ----- Load related data ------
incidence_dat <- read_excel("data/incidence_2017_2025_w_sim.xlsx")
# shapefiles
# prereform_dat <- read_rds("data/lookup_area_prereform.rds") %>%
#   st_transform(fm_crs_set_lengthunit(st_crs("EPSG:9210"), "km"))

# only include records w/ discrepancies in address-based and coordinate-based pre-reform polygons
assignment_distance <- incidence_dat %>%
  filter(!is.na(id_space_lvl3_address), !is.na(id_space_lvl3_coordinate)) %>%
  filter(id_space_lvl3_address != id_space_lvl3_coordinate) %>%
  left_join(
    prereform_dat %>%
      select(id_space_lvl3) %>%
      rename(
        geometry_addr = geometry
      ),
    by = join_by(id_space_lvl3_address == id_space_lvl3)
  ) %>%
  left_join(
    prereform_dat %>%
      select(id_space_lvl3) %>%
      rename(
        geometry_coord = geometry
      ),
    by = join_by(id_space_lvl3_coordinate == id_space_lvl3)
  ) %>%
  mutate(
    distance_centroid_km = map2_dbl(
      geometry_addr,
      geometry_coord,
      \(a, b) st_distance(st_centroid(a), st_centroid(b))
    ),
    distance_border_km = map2_dbl(
      geometry_addr,
      geometry_coord,
      \(a, b) st_distance(a, b)
    )
  ) %>%
  select(
    id_space_lvl3_address, id_space_lvl3_coordinate, distance_border_km, distance_centroid_km
  )


#------- Plots ---------
## Visualize distance between edges-------
ggplot(assignment_distance, aes(x = distance_border_km)) +
  geom_density(color = "royalblue", fill = "cornflowerblue", alpha = 0.4) +
  geom_rug(alpha = 0.2) +
  labs(
    title = "Distribution of distance between mismatched polygons",
    x = "Distance between nearest edges (km)"
  )

## Visualize distance between edges excluding neighbors-------
assignment_distance %>%
  filter(distance_border_km > 0) %>%
  ggplot(aes(x = distance_border_km)) +
    geom_density(color = "royalblue", fill = "cornflowerblue", alpha = 0.4) +
    geom_rug(alpha = 0.2) +
    labs(
      title = "Distribution of distance between mismatched polygons (excluding neighbors)",
      x = "Distance between nearest edges (km)"
    )

## Visualize binned distance-------
assignment_distance  %>%
  mutate(
    distance_binned = if_else(distance_border_km >= 20, 20,
                              floor(distance_border_km / 2) * 2)
  )  %>%
  ggplot(aes(x = distance_binned)) +
  geom_histogram(
    binwidth = 2,
    fill = "cornflowerblue",
    color = "white"
  ) +
  geom_text(
    stat = "bin",
    aes(label = after_stat(count)),
    binwidth = 2,
    vjust = -0.5,
    size = 3
  ) +
  scale_x_continuous(
    breaks = c(seq(0, 18, by = 2), 20),
    labels = c(seq(0, 18, by = 2), ">=20")
  ) +
  labs(
    title = "Distribution of distance between mismatched polygons",
    x = "Distance between nearest edges (km)",
    y = "Count"
  ) +
  theme_minimal()
ggsave(dpi=300, height = 5, width=8,"notebooks/distance_distribution.jpeg")

## Visualize distance between centroids -------
ggplot(assignment_distance, aes(x = distance_centroid_km)) +
  geom_density(color = "royalblue", fill = "cornflowerblue", alpha = 0.4) +
  geom_rug(alpha = 0.2) +
  labs(
    title = "Distribution of distance between mismatched polygons",
    x = "Distance between centroids (km)"
  )
