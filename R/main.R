library(targets)

# Make sure that the main script file (`_targets.R`)
# is at the correct location
tar_config_set(script = "R/_targets.R")

# Visualise pipeline
tar_visnetwork()

# Run targets pipeline
tar_make()


tar_load(clean_data)
clean_data
