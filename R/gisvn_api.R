library(httr)
library(jsonlite)

# Get new commune + province using gisvn API
get_new_addr <- function(lat, lng, token="de1b1549") {
  res <- GET(
    url = "https://vn2000.vn/api/locationinfo",
    query = list(lat = lat, lng = lng, token=token)
  )

  if (status_code(res) != 200) {
    return(list(new_commune = NA, new_province = NA))
  }

  content <- content(res, as = "text", encoding = "UTF-8") |>
    fromJSON(simplifyVector = TRUE)

  tryCatch({
    props <- content$data$diachinh_sausapnhap$properties

    list(
      new_commune = props$ten_xa,
      new_province = props$ten_tinh
    )
  }, error = function(e) {
    list(new_commune = NA, new_province = NA)
  })
}
