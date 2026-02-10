# Packages ----------------------------------------------------------------
source("codes/00_packages.R", verbose = T)


# OSM ---------------------------------------------------------------------
# A 2x2 matrix
hcmc_bb <- matrix(
  data = hcmc_extent,
  nrow = 2,
  byrow = TRUE
)

# Update column and row names
colnames(hcmc_bb) <- c("min", "max")
rownames(hcmc_bb) <- c("x", "y")

# Print the matrix to the console
hcmc_bb

# Pull osf data - whatchout, takes forever
hcmc_highway <- hcmc_bb %>%
  opq() %>%
  add_osm_feature(key = "highway") %>%
  osmdata_sf()

hcmc_highway <- hcmc_highway %>%
  imap(~ if ("sf" %in% class(.x)) {
    .x %>%
      st_transform(kmproj)
  } else {
    .x
  })


# SaveRDS
saveRDS(hcmc_highway, "data/osm_highway.RDS")