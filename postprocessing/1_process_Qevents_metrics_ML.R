#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# NWM and ML prot-processing model performance evaluation
# per events
# created: 9/23/2025
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

library(lubridate)
library(tidyr)
library(ggplot2)
library(dplyr)
library(stringr)

#source <- "Y:/mmorales/"
source <- "/netfiles/ciroh/mmorales/"
obsPath <- paste0(source,"NWM_forecasts/InputData/processed_data/")
evPath <- paste0(source,"NWM_forecasts/NWM_perfUndst/teva_inputs/")
sitesPath <- paste0(source,"NWM_forecasts//InputData/Sites_selection/Final_selection/")
nwmPath <- paste0(source,"NWM_forecasts/NWM_perfUndst/nwm_data/")
savePath <- paste0(source,"NWM_forecasts/NWM_mlCorrection/output/plots/")

source(paste0(source,"NWM_forecasts/NWM_perfUndst/Codes/R_utils_perfUndst.R"))

#===========================
# Define test information
#===========================
testID <- "wq" #"1wq"
test_no <- "wq_2_1b_e"#"wq_2_e"
forecastH <- 24*3
target <- "model error"
#target <- "streamflow"

frcstPath <- paste0(source,"NWM_forecasts/NWM_mlCorrection/output/forecast/")

print(paste("Starting evaluation for",testID))

#============================
# Define sites to work with
#============================
if (testID == "wq"){
       load(paste0(sitesPath,"wq_sites.Rdata"))
       sel_sites <- unique(wq_sites$siteID)
} else if (testID == "all"){
       load(paste0(paste0(sitesPath,"selFltr_usgs_sites_NE.Rdata")))
       sel_sites <- unique(usgs_sites_fltr$site_no)
} else if (testID == "1wq"){
       sel_sites <- "01362500"
}

#========================================
# Loading selected sites
#========================================
load(paste0(paste0(sitesPath,"selFltr_usgs_sites_NE.Rdata")))
dbSites <- usgs_sites_fltr %>% rename("siteID" = "site_no") #%>%
           #filter(siteID %in% sel_sites)

#==========================
# Reading ML outputs
#==========================
mlout <- read.csv(paste0(frcstPath,"forecasts_",test_no,".csv"),header = TRUE)
mlout <- mlout %>%
         rename("dateTime" = "reference_time")

#========================================
# Loading observations
#========================================
load(paste0(obsPath,"USGS_Q_Montane_NE_hourly.Rdata"))
#NOTE: Prepared in G:\My Drive\CIROH\Codes\NWM_forecasts\Final_ProjectSecondPart\Prepare_Qobs.R

evalStart <- as.POSIXct("2019-01-01 00:00:00",format = "%Y-%m-%d %H:%M:%S",tz="UTC")
q_obs <- subset(usgs_hourly,siteID %in% dbSites$siteID & dateTime >= evalStart)
q_obs <- q_obs #%>%
         #filter(siteID %in% sel_sites)

#========================================
# Loading NWM MR
#========================================
#--- Medium Range forecast
configuration <- "medium_range_mem1"
load(paste0(nwmPath,"nwm_",configuration,"_montane.Rdata"))
head(nwm_ds)

nwm_ds <- nwm_ds #%>%
          #filter(siteID %in% sel_sites)

#========================================
# NWM forecast + USGS obs.
#========================================
# For testing
# mlDs <- mlout
# obsDs <- q_obs
# nwmDs <- nwm_ds
# frcstType <- "streamflow"
# testID <- paste0(test_id,"_",test_id2)
# forecast_horizon <- forecastH

mod_frcst <- prepare_mlObsDs(mlDs=mlout,obsDs=q_obs,nwmDs=nwm_ds,frcstType=target,
                             dbSites=dbSites,testID=test_no,forecast_horizon=forecastH)

#========================================
# Load events
#========================================
# >50%aep_events_df
load(paste0(evPath,"event_metrics/aep_events_df.Rdata"))

# Select event's data
#======================
# Only for testing, delete later
# dataset <- mod_frcst
# events <- events_df
# productType <- "forecast"

mlEvs <- get_eventData(dataset=mod_frcst,events=events_df,productType="forecast")

# Compute metrics
#======================
mlMetrics <- ml_metrics(dataset=mlEvs,productType="forecast",dbSites=dbSites)

# Save events and errors to plot spatially
#-------------------------------------------
# Specify the path to the directory you want to create
new_dir_path <- paste0(savePath,"event_metrics/")

# Check if the directory exists
if (!dir.exists(new_dir_path)) {
    # If it doesn't exist, create it
    dir.create(new_dir_path, recursive = TRUE)
}

save(mlEvs, file = paste0(savePath,"event_metrics/ml_mr_evs_montane_",test_no,".Rdata"))
save(mlMetrics, file = paste0(savePath,"event_metrics/ml_mr_metrics_montane_",test_no,".Rdata"))
write.csv(mlMetrics, file = paste0(savePath,"event_metrics/ml_mr_metrics_montane",test_no,".csv"), row.names=FALSE)
