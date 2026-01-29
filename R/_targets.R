library(targets)

tar_source("R/target_fns")
tar_option_set(packages = c("tidyverse"))

list(
  tar_target(
    xlsx_2000_2016,
    "data/incidence/2000_2016_updated.xlsx",
    format = "qs"
  ),
  tar_target(raw_data, ingest_xlsx(xlsx_2000_2016)),
  tar_target(clean_data, clean_xlsx(raw_data, decode_addr = TRUE)),
  tar_target(clean_addr, get_clean_addr(clean_data, colname = "raw_addr"))
)
