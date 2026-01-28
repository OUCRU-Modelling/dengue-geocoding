get_addr <- function(df, colname = "addr") {
  df %>% pull(var = colname) %>% unique()
}
