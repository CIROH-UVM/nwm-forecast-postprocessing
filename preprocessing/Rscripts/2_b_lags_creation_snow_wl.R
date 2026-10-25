#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Objective:
# Prepare features based on lags for SWE, snow depth and WL
# This will help our ML model to keep track of antecedent
# conditions in the catchment.
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

library(lubridate)
#library(purrr)
library(dplyr)
#library(tidyr)
#library(tidyverse)
#library(glue)

start_time <- Sys.time()

#source <- "/netfiles/ciroh/mmorales/"
source <- "Y:/mmorales/"
sitesPath <- paste0(source,"NWM_forecasts/InputData/Sites_selection/Final_selection/")
snodasPath <- paste0(source,"/NWM_forecasts/InputData/processed_data/snodas/")
wlPath <- paste0(source,"NWM_forecasts/InputData/processed_data/")
nwmPath <- paste0(source,"NWM_forecasts/NWM_perfUndst/nwm_data/")
savePath <- paste0(source,"NWM_forecasts/NWM_mlCorrection/input_features/")

#============================
# Define sites to work with
#============================
testID <- "wq" #"all"
# Load WQ sites
if (testID == "wq"){
    load(paste0(sitesPath,"wq_sites.Rdata"))
    sel_sites <- unique(wq_sites$siteID)
} else if (testID == "all"){
    load(paste0(paste0(sitesPath,"selFltr_usgs_sites_NE.Rdata")))
    sel_sites <- unique(usgs_sites_fltr$site_no)
}

#===================================
# Load datasets
#===================================
load(paste0(snodasPath,"snodas.Rdata"))
snodas <- snodas %>%
        filter(siteID %in% sel_sites)

load(paste0(wlPath,"WL_montane_NE.Rdata"))
wl_obs <- usgs_wl %>%
        filter(siteID %in% sel_sites)

#=================================
# FUNCTIONS
#=================================
#------ Funtion to load data
load_var_data <- function(config_name, path) {
    # Construct file path
    file_path <- paste0(path,"/nwm_",config_name,"_montane.Rdata")

    # Load into a temporary environment to avoid overwriting global variables
    temp_env <- new.env()
    load(file_path, envir = temp_env)

    # Get the object (assuming it's named 'ana_frc' or 'mr_frc' inside the file)
    data <- temp_env[[names(temp_env)[1]]]
    return(data)
}

#------ Function to process snodas lags
process_snodas <- function(ref_times,snodas_data){

    snow_data_prepared <- snodas_data %>%
                          mutate(join_date = as.Date(dateTime) + days(1)) %>%
                          select(-units)

    # Let's create a matching 'join_date' based on the reference_time
    snow_data <- ref_times %>%
                     mutate(join_date = as.Date(reference_time))

    # Perform the join
    snow_data <- snow_data %>%
               left_join(snow_data_prepared, by = c("siteID", "join_date")) %>%
               select(-join_date,-dateTime) %>%
               rename("swe_lag24" = "snodas_SNEQV",
                      "snowDepth_lag24" = "snodas_SNOWH")

    return(snow_data)
}

#----- Function to create rolling windows
prepare_wl_lags <- function(ref_grid, wl_data, lags_list) {

    result <- ref_grid

    for (h in lags_list) {
        # 1. Create a temporary lookup for this specific lag
        # We shift the observation time forward so it matches the 'future' reference_time
        temp_lookup <- wl_data %>%
                       transmute(
                           siteID,
                           match_time = dateTime + hours(h),
                           !!paste0("stage_lag", h) := stage_cm
                       )

        # 2. Join it to the grid
        result <- result %>%
                  left_join(
                      temp_lookup,
                      by = c("siteID" = "siteID", "reference_time" = "match_time")
                  )
    }

    return(result)
}

#========================================
# Apply function
#========================================
# Define input parameters
#----------------------------
lags  <- c(4,6,8)

# Apply functions
print("--- Applying functions")

# Load forecast data to get the reference times per site
forecast_data    <- load_var_data(config_name = "medium_range_mem1", path = nwmPath)
forecast_data <- forecast_data %>% filter(siteID %in% sel_sites) %>%
                 mutate(configuration_name = "medium_range_mem1") %>% select(reference_time,siteID) %>%
                 distinct()

# Let's process the snow and wl features
snow_features <- process_snodas(ref_times = forecast_data,snodas_data = snodas)
wl_features <- prepare_wl_lags(ref_grid = forecast_data, wl_data = wl_obs, lags_list = lags)

#========================================
# Save features
#========================================
save(snow_features, file = paste0(savePath,"snow_features.Rdata"))
save(wl_features, file = paste0(savePath,"wl_features.Rdata"))

print("Procesing finished!...")

end_time <- Sys.time()
time_taken_seconds <- as.numeric(end_time - start_time, units = "secs")
time_taken_hours <- time_taken_seconds / 3600
print(paste("Script took", round(time_taken_hours, 2), "hours to run."))
