source("codes/00_packages.R", verbose=TRUE)
source("R/gen_mapping_key.R")
library(tidylog)
library(readxl)
library(sf)
library(patchwork)

# ====== Load incidence data =========
data_bundle <- read_rds("data/data_for_analysis_gisvn.RDS")
incidence_data <- data_bundle$incidence_data
prereform_lookup <- data_bundle$spatial_area_lvl3_prereform
postreform_lookup <- data_bundle$spatial_area_lvl3_postreform

# summary before salvaging post reform id
incidence_data %>%
  mutate(
    time_period = if_else(
      date_hosp < as.Date("2025-08-01"),
      "pre-reform", "post-reform"
    )
  ) %>%
  group_by(time_period) %>%
  summarize(
    no_prereform_lvl3 = sum(is.na(id_space_lvl3)),
    no_postreform_lvl3 = sum(is.na(id_space_lvl3_postreform)),
  )

# View prereform and postreform
ggplot() +
  geom_sf(data = prereform_lookup, fill = "red", color="red", alpha=.2) +
  geom_sf(data = postreform_lookup %>%
            filter(name_2 != "Côn Đảo"), fill = "cornflowerblue",
            color = "cornflowerblue", alpha=.4)


# ========= Creating the mapping table ==================

## -------- Map pre-reform to post-reform polygon by checking there intersection ---------
reform_intersect <- st_intersection(
  prereform_lookup %>% select(id_space_lvl3),
  postreform_lookup %>% select(id_space_lvl3_postreform))

# get the entries where intersection is a polygon
reform_intersect <- st_collection_extract(reform_intersect, type = "POLYGON")

# check the area of the intersection to determine threshold for mapping
intersect_area <- reform_intersect %>%
  mutate(
    area_intersect = st_area(geometry) %>% as.numeric()
  )

# Get data.frame of mapping from pre- reform polygon to post- reform polygon
# Each row is a pre- reform polygon associated with the post- reform polygon(s)
# (i.e, a  pre- reform commune that are splitted into 2 before merging into a new commune will have 2 rows in the data.frame)
# The data frame contains the following info
# - pre- reform polygon info: id_space_lvl3, name_2 (district name), name_3 (commune name), prereform_shape
# - post- reform polygon info: id_space_lvl3_postreform, new_commune_name
# - area of intersect
# - plot for overlap between pre- reform and post- reform polygon
reform_intersect_viz <- intersect_area %>%
  filter(round(area_intersect, digits = 1) > 0) %>%
  # select(-area_intersect) %>%
  st_drop_geometry() %>%
  left_join(
    prereform_lookup %>% select(id_space_lvl3, name_2, name_3) %>% rename(prereform_shape = geometry),
    by = "id_space_lvl3"
  ) %>%
  left_join(
    postreform_lookup %>%
      select(id_space_lvl3_postreform, name_2) %>%
      rename(
        postreform_shape = geometry,
        new_commune_name = name_2
      ),
    by = "id_space_lvl3_postreform"
  ) %>%
  mutate(
    prop_area = as.numeric(area_intersect)/as.numeric(st_area(prereform_shape)),
    viz_overlap = pmap(list(
      area = area_intersect, pre_name=name_3, pre_name_2=name_2, post_name=new_commune_name,
      pre_shape=prereform_shape, post_shape=postreform_shape,
      prop_area=prop_area),
                       \(area, pre_name, pre_name_2, post_name, pre_shape, post_shape, prop_area){
      ggplot() +
        geom_sf(fill="red", alpha=0.2, data=pre_shape) +
        geom_sf(fill="cornflowerblue", alpha=0.2, data=post_shape) +
        labs(
          title = paste0("Prereform: ", pre_name, " (District ", pre_name_2,")\nMerged into: ", post_name),
          subtitle = paste0("Area of intersection (km2): ", round(area, digits = 2),
                            "\nProp intersect: ", round(prop_area, digits = 4)),
          caption = "Prop intersect = (Area of intersection)/(Area of pre-reform commune)"
        )
    })
  )

# reform_intersect_viz$viz_overlap[[1]]


# Data.frame how post- reform communes is formed fr pre- reform ones
# Each row is a post- reform communes with the following info
# - post- reform polygon info: id_space_lvl3_postreform, new_commune_name, post_shape (i.e. the polygon)
# - info of pre- reform communes that made up the current post- reform polygon: pre_names (list of communes names), pre_shapes
#                                                 (list of polygons)
# - areas (list of areas of intersection)
# - plot for post- reform polygon and their associated pre- reform areas
postreform_merging_viz <- intersect_area %>%
  filter(round(area_intersect, digits = 1) > 0) %>%
  # select(-area_intersect) %>%
  st_drop_geometry() %>%
  left_join(
    prereform_lookup %>% select(id_space_lvl3, name_2, name_3) %>% rename(prereform_shape = geometry),
    by = "id_space_lvl3"
  ) %>%
  left_join(
    postreform_lookup %>%
      select(id_space_lvl3_postreform, name_2) %>%
      rename(
        postreform_shape = geometry,
        new_commune_name = name_2
      ),
    by = "id_space_lvl3_postreform"
  ) %>%
  group_by(id_space_lvl3_postreform) %>%
  summarize(
    new_commune_name = new_commune_name[1],
    post_shape = list(postreform_shape[1]),   # expect same post polygon repeated per row -> take first one
    pre_names  = list(name_3),
    pre_names_2  = list(name_2),
    pre_shapes = list(prereform_shape),
    areas      = list(area_intersect)
  ) %>%
  mutate(
    # Visualize how each new commune is merged from pre-reform ones
    merging_viz = pmap(
      list(post_name  = new_commune_name, post_shape = post_shape,
        pre_names  = pre_names, pre_names_2 = pre_names_2, pre_shapes = pre_shapes, areas = areas
      ),
      \(post_name, post_shape, pre_names, pre_names_2, pre_shapes, areas) {
        # rebuild an sf object from the list of pre-reform shapes + names
        pre_sf <- st_sf(
          pre_name = pre_names,
          geometry = st_sfc(pre_shapes, crs = st_crs(post_shape[[1]]))
        )

        ggplot() +
          geom_sf(data = pre_sf, aes(fill = pre_name), color = "red", alpha = 0.2) +
          geom_sf(data = post_shape, fill = "grey", color="black", alpha=.5) +
          theme_bw() +
          labs(
            title = paste0("Post-reform: ", post_name),
            fill = "pre-reform",
            # subtitle = "Blue outline = post-reform boundary; colored polygons = pre-reform units merged in",
            caption = paste0("Made up of: ", paste0(
                              unlist(pre_names), " (", unlist(pre_names_2) ,")",
                              collapse = ", "),
                             "\nIntersection area (km2): ",  paste(round(areas, digits=2), collapse = ", "))
          )
      }
    )
  )

# postreform_merging_viz$merging_viz[[1]]

### ------- Save pre- to post- reform polygons plots ----------
# Save multiple images each with 24 plots of pre-reform communes is merged into a new one
plots_per_page <- 12

plot_groups <- split(postreform_merging_viz$merging_viz,
                     ceiling(seq_along(postreform_merging_viz$merging_viz) / plots_per_page))

grid_plots <- map(plot_groups, ~ wrap_plots(.x, ncol = 4, widths = 10, heights = 6) &
                    theme(
                      axis.text  = element_blank(),
                      plot.margin  = margin(t = 10, r = 20, b = 14, l = 20),  # more bottom margin for caption room
                      # plot.caption = element_text(size = 6, hjust = 0),
                      plot.caption = element_blank(),
                      plot.title   = element_text(size = 8),
                      legend.title  = element_text(size = 8),
                      legend.text   = element_text(size = 6),
                      legend.key.size = unit(0.4, "cm")
                    ))

# grid_plots[[1]]

# save each group as its own image
iwalk(grid_plots, ~ ggsave(
  filename = paste0("figures/postreform_viz/postreform_merging_viz_page_", .y, ".png"),
  plot = .x,
  width = 14, height = 6,
  dpi = 300,
  limitsize = FALSE
))

# check 1 in post-reform lookup that is not in the reform_intersect_viz
# i.e., polygons for some reasons considered to be not intersecting with ANY pre-reform polygons

## ------- Get pre-reform full merge ---------
# Get entries where mapping from old to new is 1 -> 1
# i.e., get communes that were not splitted when merging into a new commune
# this is done by checking the proportion (area of intersect)/(area of prereform polygon)

# check the distribution first
reform_intersect_viz %>%
  mutate(
    area_prereform = st_area(prereform_shape),
    prop_area = area_intersect/as.numeric(area_prereform)
  ) %>%
  select(id_space_lvl3, name_3, prop_area) %>%
  ggplot(aes(x = prop_area)) +
    geom_density(fill = "cornflowerblue") +
    geom_vline(xintercept = .99)

# compute the proportion to determine which communes were not splitted during merging
no_split_viz <- reform_intersect_viz %>%
  filter(prop_area >= .99)

no_split_viz$viz_overlap[[1]]

### ------ Save plots for communes that are not splitted during merge ------
plots_per_page <- 12
plot_groups <- no_split_viz %>%
  arrange(prop_area) %>%
  { split(.$viz_overlap, ceiling(seq_along(.$viz_overlap) / plots_per_page)) }

grid_plots <- map(plot_groups, ~ wrap_plots(.x, ncol = 4,
                                            widths = 8, height=6) &
                    theme_bw() &
                    theme(
                      axis.text  = element_blank(),
                      plot.margin = margin(4, 4, 4, 4),
                      plot.caption = element_text(size = 5, hjust = 0),
                      plot.title   = element_text(size = 6),
                      plot.subtitle = element_text(size = 5)
                    ))

# grid_plots[[1]]

# save each group as its own image
iwalk(grid_plots, ~ ggsave(
  filename = paste0("figures/no_split_communes/no_split_communes_", .y, ".png"),
  plot = .x,
  width = 14, height = 6,
  dpi = 300,
  limitsize = FALSE
))

## ------- Cross check with VietMap mapping --------
mapping_table <- read_excel("data/shapefiles/admin_mapping_old_to_new_10_25.xlsx") %>%
  filter(city_name_new == "Thành Phố Hồ Chí Minh") # we only care for HCMC here

# only keep entries where mapping from old to new is 1 -> many
single_map_table <- mapping_table %>%
  group_by(ward_name_old) %>%
  filter(n()<2) %>%
  ungroup()

# ======= Update post reform commune in incidence ================
no_split_mapping <- no_split_viz %>%
 select(id_space_lvl3, id_space_lvl3_postreform) %>%
 rename(id_space_lvl3_postreform_2 = id_space_lvl3_postreform)

incidence_data_2 <- incidence_data %>%
  left_join(
    no_split_mapping, by = "id_space_lvl3"
  ) %>%
  mutate(
    id_space_lvl3_postreform = coalesce(
      id_space_lvl3_postreform,
      id_space_lvl3_postreform_2
    )
  ) %>%
  select(-id_space_lvl3_postreform_2)

# was able to assign 36,785 more records to be assigned to a post-reform polygon
incidence_data_2 %>%
  mutate(
    time_period = if_else(
      date_hosp < as.Date("2025-08-01"),
      "pre-reform", "post-reform"
    )
  ) %>%
  group_by(time_period) %>%
  summarize(
    no_prereform_lvl3 = sum(is.na(id_space_lvl3)),
    no_postreform_lvl3 = sum(is.na(id_space_lvl3_postreform)),
  )

## ----- update incidence in the data bundle -------
data_bundle$incidence_data <- incidence_data_2
write_rds(data_bundle, "data/data_for_analysis_gisvn.RDS")


