library(stringr)

get_clean_addr <- function(df, colname = "addr") {
  raw_addrs <- df %>%
    pull(var = colname)
  print(paste0("Number of addresses before cleaning: ", length(raw_addrs)))

  cleaned_addrs <- raw_addrs %>%
    str_to_lower(locale = "vi_VN") %>%
    trimws(whitespace = "[ \t\r\n,]") %>%
    unique()
  print(paste0("Number of addresses after cleaning: ", length(cleaned_addrs)))

  cleaned_addrs
}
