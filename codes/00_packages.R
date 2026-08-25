# Packages ----------------------------------------------------------------
library("osmdata")
library("sf")
library("terra")
library("fmesher")
library("tidyverse")
library("readxl")
library("qs2")
library("writexl")

# VN projection and HCMC spatial extent -----------------------------------
# Roughly HCMC spatial extent
cropvector <- c(106.2, 107.2, 10.2, 11.3)
hcmc_extent <- ext(cropvector)

#VN projection
kmproj <- fm_crs_set_lengthunit(st_crs("EPSG:9210"), "km")

