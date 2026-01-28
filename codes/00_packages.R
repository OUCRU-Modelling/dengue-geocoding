# Packages ----------------------------------------------------------------
install.packages("remotes")
remotes::install_gitlab ("ropensci/osmdata")
remotes::install_github("r-spatial/sf")
remotes::install_github("rspatial/terra")
remotes::install_github("inlabru-org/fmesher")

library("osmdata")
library("sf")
library("terra")
library("fmesher")

