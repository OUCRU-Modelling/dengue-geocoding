library(readxl)
library(janitor) %>% suppressPackageStartupMessages()

ingest_xlsx <- function(path) {
  sheets <- excel_sheets(path)

  map(seq(1, length(sheets)), \(s_num) {
    read_excel(path, sheet = s_num) %>%
      clean_names() %>%
      suppressWarnings()
  }) %>%
    list_c()
}
