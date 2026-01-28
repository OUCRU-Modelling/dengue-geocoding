# Packages ----------------------------------------------------------------
#install.packages("remotes")
#install.packages("pak")


#remotes::install_gitlab ("ropensci/osmdata")
#remotes::install_github("r-spatial/sf")
#remotes::install_github("rspatial/terra")
#remotes::install_github("inlabru-org/fmesher")
#remotes::install_github("sfirke/janitor")
#pak::pak("tidyverse/tidyverse")
library("osmdata")
library("sf")
library("terra")
library("fmesher")
library("tidyverse")



# VN projection and HCMC spatial extent -----------------------------------------
# Roughly HCMC spatial extent
cropvector <- c(106.2, 107.2, 10.2, 11.3)
hcmc_extent <- ext(cropvector)

#VN projection
kmproj <-  fm_crs_set_lengthunit(st_crs("EPSG:9210"),  "km") 
