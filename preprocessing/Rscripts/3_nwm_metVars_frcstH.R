#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Objective:
# Prepare features from NWM medium-range forcings
# This will help our ML model to keep track of what meteorological
# conditions are happening along the forecast
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

library(lubridate)
library(dplyr)
library(glue)
library(tidyverse)

start_time <- Sys.time()

source <- "/netfiles/ciroh/mmorales/"
#source <- "Y:/mmorales/"
sitesPath <- paste0(source,"NWM_forecasts/InputData/Sites_selection/Final_selection/")
nwmPath <- paste0(source,"/NWM_forecasts/InputData/processed_data/nwm_forecast/")
nwmQPath <- paste0(source,"NWM_forecasts/NWM_perfUndst/nwm_data/")
savePath <- paste0(source,"NWM_forecasts/NWM_mlCorrection/input_features/")

#=================================
# Define sites to work with
#=================================
testID <- "wq" #"1wq" #"all"
# Load WQ sites
if (testID == "wq"){
    load(paste0(sitesPath,"wq_sites.Rdata"))
    sel_sites <- unique(wq_sites$siteID)
} else if (testID == "all"){
    load(paste0(paste0(sitesPath,"selFltr_usgs_sites_NE.Rdata")))
    sel_sites <- unique(usgs_sites_fltr$site_no)
} else if (testID == "1wq"){
    sel_sites <- "01362500"
}

print(testID)
print(sel_sites)

#=================================
# FUNCTIONS
#=================================
#------ Funtion to load data
load_var_data <- function(var_name, config_name, path) {
    # Construct file path
    file_path <- paste0(path,config_name,"/",var_name,"/nwm_",config_name,"_montane.Rdata")

    # Load into a temporary environment to avoid overwriting global variables
    temp_env <- new.env()
    load(file_path, envir = temp_env)

    # Get the object (assuming it's named 'ana_frc' or 'mr_frc' inside the file)
    data <- temp_env[[names(temp_env)[1]]]
    return(data)
}

#========================================
# Apply function
#========================================
var_list <- c("RAINRATE","T2D","PSFC","Q2D","SWDOWN","LWDOWN","U2D","V2D")
all_features_list <- list()

#---- Streamflow
print("--- Processing Variable: Streamflow")

config_name <- "medium_range_mem1"
load(paste0(nwmQPath,"/nwm_",config_name,"_montane.Rdata"))
frcst <- nwm_ds %>% filter(siteID %in% sel_sites) %>%
         select(-comid) %>%
         rename("q_nwm_mr" = "value")

# Store inside the list
all_features_list[["Q"]] <- frcst

#---- meteorological data (all forcings)
for (v in var_list) {
    print(paste("--- Processing Variable:", v))

    # Load data specifically for this variable
    forecast_data    <- load_var_data(var_name = v, config_name = "forcing_medium_range", path = nwmPath)
    forecast_data <- forecast_data %>% filter(siteID %in% sel_sites) %>%
                     rename(!!glue("{v}_nwm_mr") := "value") %>%
                     select(-variable_name,-location_id)

    if (v == "RAINRATE"){
        forecast_data <- forecast_data %>%
                          mutate(lead_time = as.numeric(value_time - reference_time),
                                 nwmVersion = sub("_.*", "", configuration_name),
                                 cycle = hour(reference_time)) %>%
                          select(-configuration_name)
    } else {
        forecast_data <- forecast_data %>%
                         select(-configuration_name)
    }

    all_features_list[[v]] <- forecast_data

    # Cleanup: Explicitly remove large objects to free RAM before next variable
    rm(forecast_data)
    gc() # Garbage collection
}

# Final Join: Merge the dataframes in the list into one big table
nwm_frcst <- all_features_list %>%
                    reduce(full_join, by = c("siteID", "reference_time", "value_time"))

# coalesce selects the columns with the most data
nwm_frcst <- nwm_frcst %>%
                    mutate(nwmVersion = coalesce(nwmVersion.x, nwmVersion.y),
                           cycle = coalesce(cycle.x, cycle.y),
                           lead_time = coalesce(lead_time.x, lead_time.y)) %>%
                    select(-nwmVersion.x, -nwmVersion.y, -cycle.x, -cycle.y, -lead_time.x, -lead_time.y)

#========================================
# Save features
#========================================
save(nwm_frcst, file = paste0(savePath,"nwm_frcst_",testID,".Rdata"))

print("Done!...")

end_time <- Sys.time()
time_taken_seconds <- as.numeric(end_time - start_time, units = "secs")
time_taken_hours <- time_taken_seconds / 3600
print(paste("Script took", round(time_taken_hours, 2), "hours to run."))
