library(targets)

tar_source("R/target_fns")
tar_option_set(packages = c("tidyverse"))

list(
  tar_target(
    xlsx_2000_2016,
    "data/incidence/2000_2016_updated.xlsx",
    format = "qs"
  ),
  tar_target(clean_data, ingest_xlsx(xlsx_2000_2016))
)
