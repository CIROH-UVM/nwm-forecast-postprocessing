#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Objective:
# Prepare features based on lags for Q NWM
# This will help our ML model to keep track of antecedent
# conditions in the catchment.
#
# NOTE: Important to remember that variables in the past could
# be sourced from the AnA Ext., AnA, and MR
# depending on the lead time.
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

library(slider)
library(lubridate)
library(purrr)
library(dplyr)
library(tidyr)
library(tidyverse)
library(glue)

start_time <- Sys.time()

source <- "/netfiles/ciroh/mmorales/"
#source <- "Y:/mmorales/"
sitesPath <- paste0(source,"NWM_forecasts/InputData/Sites_selection/Final_selection/")
nwmPath <- paste0(source,"NWM_forecasts/NWM_perfUndst/nwm_data/")
savePath <- paste0(source,"NWM_forecasts/NWM_mlCorrection/input_features/")

#===============================
# IMPORTANT
#===============================
# NOTE:
# See notes on 1_b_rolling_windows_Q.R

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

#------ Function to process one variable across all sites/refs/windows
process_variable <- function(analysis_data, analysisExt_data, forecast_data, lags) {

    # Create a grid of all tasks for this variable
    task_grid <- expand_grid(
        site = target_sites,
        ref_time = target_refs,
        #lag_size = lags_list
    )

    # Map across the grid
    res_list <- pmap(task_grid, function(site, ref_time) {
        prepare_hybrid_windows(site, ref_time, analysis_data, analysisExt_data, forecast_data, lags)
    })

    # Combine everything at once (much faster than pmap_dfr)
    res <- bind_rows(res_list)

    # Clean up the list immediately to free up RAM
    rm(res_list)
    gc()

    # Pivot to ensure each window size is its own column
    # This collapses the multiple window rows into one row per value_time
    res_wide <- res %>%
                group_by(siteID, reference_time, value_time) %>%
                #summarise(across(everything(), ~ {x <- .x[!is.na(.x)]
                #                                  if(length(x) > 0) x[1] else as.numeric(NA)}), .groups = "drop")
                summarise(across(contains("lag"), ~first(na.omit(.))), .groups = "drop")

    #print(summary(res_wide))

    return(res_wide)
}

#----- Function to create rolling windows
prepare_hybrid_windows <- function(site, ref_time, analysis_data, analysisExt_data, forecast_data, lags){

    # 1. Prepare "Truth" (Analysis) and "Forecast" (Hindcasts) dataframes
    # 2. Join them based on the 'valid_time' (the actual time the value represents)

    # Each dataset to be processed has a column with the variable name in it.
    # Let's extract it and store it for later
    #var_name <- unique(forecast_data$variable_name)

    # As a maximum, we will consider withows of 48h.
    limit_date <- ref_time - hours(72)

    # Filter and clean repetitions on Analysis Extended for everything BEFORE ref_time
    #-----------------------------------------------------------------------------------
    past_ext <- analysisExt_data %>%
            filter(siteID == site, reference_time <= ref_time & value_time >= limit_date) %>%
            group_by(value_time) %>%
            slice_max(order_by = reference_time, n = 1, with_ties = FALSE) %>%
            ungroup()

    if (nrow(past_ext) > 0) {
        limit_ext <- max(past_ext$value_time)
    } else {
        limit_ext <- as.POSIXct(NA)
    }

    # Filter and clean repetitions on Analysis for everything BEFORE ref_time
    #-----------------------------------------------------------------------------------
    past <- analysis_data %>%
                filter(siteID == site, reference_time <= ref_time & value_time > limit_ext) %>%
                group_by(value_time) %>%
                slice_max(order_by = reference_time, n = 1, with_ties = FALSE) %>%
                ungroup()

    # Filter Forecast issued AT ref_time for everything AFTER ref_time
    #-----------------------------------------------------------------------------------
    #future <- forecast_data %>% filter(siteID == site, reference_time == ref_time & value_time > ref_time)
    future <- forecast_data %>% filter(siteID == site, reference_time == ref_time) # Frcts always have value_times > ref_time

    # Stitch them together
    #---------------------
    stitched <- bind_rows(past, past_ext, future) %>% arrange(value_time)

    # NOTE: It is possible to have missing data, thus, since the silde window doesn't consider time
    # We will make sure that the time series are complete and ordered
    # Populate missing values
    lagW <- stitched %>%
                 complete(value_time = seq(min(value_time), max(value_time), by = "hour")) %>%
                 mutate(siteID = site,
                        reference_time = ref_time) %>%
                 group_by(siteID) %>% arrange(value_time)

    # For testing:
    #write.csv(stitched, file = paste0(savePath,"tests/","prueba_stitched_lag.csv"), row.names=FALSE)

    # Get lag values on the stitched timeline
    #-----------------------------------------------------
    for (l in lags){
        lagW <- lagW %>%
                mutate(
                    !!glue("qnwm_lag{l}") := lag(value,n= l))
    }

    # For testing:
    #write.csv(lagW, file = paste0(savePath,"tests/","prueba_lagW.csv"), row.names=FALSE)

    # Let's filter the rolling values, to only values within the forecast
    lagW <- lagW %>% filter(value_time > ref_time) %>% select(-value,-location_id,-configuration_name,-comid,-nwmVersion) %>%
             relocate(value_time, .after = siteID)

    return(lagW)
}

#========================================
# Apply function
#========================================
# Define sites to work with
#----------------------------
testID <- "wq" #"1wq" # #"all"
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

# Define input parameters
#----------------------------
lags_list  <- c(1, 3, 6, 24)

# Uncomment for testing
#sel_sites <- c("01362232","013621955")
#test_refst <- as.POSIXct("2019-06-22 00:00:00",format = "%Y-%m-%d %H:%M:%S",tz="UTC")

# Apply functions
print("--- Processing Variable Q NWM")

# 1. Load data specifically for this variable
analysis_data    <- load_var_data(config_name = "analysis_assim", path = nwmPath)
analysis_data <- analysis_data %>% filter(siteID %in% sel_sites)
analysisExt_data <- load_var_data(config_name = "analysis_assim_extend", path = nwmPath)
analysisExt_data <- analysisExt_data %>% filter(siteID %in% sel_sites)
forecast_data    <- load_var_data(config_name = "medium_range_mem1", path = nwmPath)
forecast_data <- forecast_data %>% filter(siteID %in% sel_sites) %>%
                 mutate(configuration_name = "medium_range_mem1") %>% select(-lead_time,-cycle)
#forecast_data <- forecast_data %>% filter(siteID %in% sel_sites & reference_time <= test_refst) %>% # Only for test
#                 mutate(configuration_name = "medium_range_mem1") %>% select(-lead_time,-cycle)

# Define additional input parameters
target_sites <- unique(forecast_data$siteID)
target_refs  <- unique(forecast_data$reference_time)

# Only for testing
print(target_sites)
print(min(target_refs))
print(max(target_refs))

# 2. Run the processing grid (the process_variable function from before)
# This returns a wide dataframe for THIS variable
cat("Calculating windows for all sites/refs...\n")
lag_qVars <- process_variable(analysis_data, analysisExt_data, forecast_data, lags = lags_list)

# 3. Cleanup: Explicitly remove large objects to free RAM before next variable
rm(analysis_data, analysisExt_data, forecast_data)
gc() # Garbage collection

#========================================
# Save features
#========================================
save(lag_qVars, file = paste0(savePath,"lag_qVars_",testID,".Rdata"))

print("Procesing finished!...")

end_time <- Sys.time()
time_taken_seconds <- as.numeric(end_time - start_time, units = "secs")
time_taken_hours <- time_taken_seconds / 3600
print(paste("Script took", round(time_taken_hours, 2), "hours to run."))
