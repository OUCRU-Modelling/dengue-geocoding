library(stringi)

clean_xlsx <- function(df, decode_addr = FALSE) {
  df %>%
    mutate(
      id = if_else(is.na(maso), ma_moi_bc, maso),
      # sometimes addr have ID in it, remove if it's the case
      addr = if_else(
        !is.na(id),
        # need coalesce since if_else evaluate str_remove regardless of whether condition is met
        str_remove(diachi, coalesce(id, " ")),
        diachi
      ),
      # if specified, encode address from TCVN/VISCII to UTF-8 (i.e. resolve mojibake)
      addr = if (decode_addr) {
        stri_trans_general(addr, id = "Latin-ASCII")
      } else {
        addr
      },
      # generate raw address to geocode
      raw_addr = paste0(
        case_when(
          !is.na(addr) ~ addr,
          !is.na(ap) ~ ap,
          .default = ""
        ),
        # handle PX coded KHONG RO
        if_else(
          is.na(px) | px == "KHONG RO",
          "",
          paste0(", phường ", px)
        ),
        ", quận ",
        qh,
        ", TP.HCM"
      )
    )
}
