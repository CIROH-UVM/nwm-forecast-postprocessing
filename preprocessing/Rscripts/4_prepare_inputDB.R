#:::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Prepare final input database for ML correction model
# Main inputs:
# Meteorological attributes
# Catchment attributes
# Target: Qobs or Q error
#:::::::::::::::::::::::::::::::::::::::::::::::::::

library(dplyr)
library(arrow) # To work with parquets
library(tidyr)

source <- "/netfiles/ciroh/mmorales/"
#source <- "Y:/mmorales/"
sitesPath <- paste0(source,"NWM_forecasts/InputData/Sites_selection/Final_selection/")
nwmPath <- paste0(source,"NWM_forecasts/NWM_perfUndst/nwm_data/")
dataPath <- paste0(source,"NWM_forecasts/NWM_mlCorrection/input_features/")
attsPath <- paste0(source,"NWM_forecasts/NWM_perfUndst/teva_inputs/met_catchment_attributes/")
obsPath <- paste0(source,"NWM_forecasts/InputData/processed_data/")
savePath <- paste0(source,"NWM_forecasts/NWM_mlCorrection/final_inputDb/")

#============================
# Define sites to work with
#============================
testID <- "wq" #"1wq" #"all"
test_no <- 2
if (testID == "wq"){
       load(paste0(sitesPath,"wq_sites.Rdata"))
       sel_sites <- unique(wq_sites$siteID)
} else if (testID == "all"){
       load(paste0(paste0(sitesPath,"selFltr_usgs_sites_NE.Rdata")))
       sel_sites <- unique(usgs_sites_fltr$site_no)
} else if (testID == "1wq"){
       sel_sites <- "01362500"
}

#================================================
# Load window features
#================================================
# Meteorological attributes
#----------------------------
load(paste0(dataPath,"all_rollW_metVars_",testID,".Rdata"))
head(rollW_metVars)

# Streamflow
#-------------
load(paste0(dataPath,"rollW_qVars_",testID,".Rdata"))
head(rollW_qVars)

#================================================
# Load lagged features
#================================================
# Streamflow
#-------------
load(paste0(dataPath,"lag_qVars_",testID,".Rdata"))
head(lag_qVars)

# Water level
#-------------
load(paste0(dataPath,"wl_features.Rdata"))
head(wl_features)
wl_features <- wl_features %>% filter(siteID %in% sel_sites)

# SWE and Snow depth
#---------------------
load(paste0(dataPath,"snow_features.Rdata"))
head(snow_features)
snow_features <- snow_features %>% filter(siteID %in% sel_sites)

#================================================
# Load NWM current times within forecast horizon
#================================================
# Only streamflow
#config_name <- "medium_range_mem1"
#load(paste0(nwmPath,"/nwm_",config_name,"_montane.Rdata"))
#frcst <- nwm_ds %>% filter(siteID %in% sel_sites) %>%
#         select(-comid) %>%
#         rename("q_nwm_mr" = "value")

#---- Streamflow + forcings
load(paste0(dataPath,"nwm_frcst_wq.Rdata")) # NOTE: I haven't processed all the 143 sites yet
frcst <- nwm_frcst %>% filter(siteID %in% sel_sites) #%>%
         #select(-comid)

#================================================
# Load Q Obs
#================================================
load(paste0(obsPath,"USGS_Q_Montane_NE_hourly.Rdata"))

q_obs <- usgs_hourly %>% filter(siteID %in% sel_sites)
q_obs$qobs_cfs <- NULL

# Populate missing values
q_obs <- q_obs %>%
         group_by(siteID) %>%
         complete(dateTime = seq(min(dateTime), max(dateTime), by="hour")) %>%
         arrange(siteID,dateTime) %>%
         as.data.frame()

limit <- as.POSIXct("2019-01-01 00:00:00",format = "%Y-%m-%d %H:%M:%S",tz="UTC")

q_obs <- q_obs %>% filter(dateTime >= limit) %>%
         rename("value_time" = "dateTime")

#=============================
# Load catchment attributes
#=============================
load(paste0(attsPath,"sel_atts_nhdplus_2025.Rdata"))
head(sel_atts)

catch_atts <- sel_atts %>%
              #select(-comid,-agency_cd,-station_nm,-dec_lat_va,-dec_long_va) %>%
              select(-comid,-agency_cd,-station_nm,-dec_lat_va,-dec_long_va) %>%
              filter(siteID %in% sel_sites)

catch_atts_list <- names(catch_atts)[2:ncol(catch_atts)]

#================================================
# Join features into a single dataset
#================================================
input_db <- frcst %>%
               left_join(rollW_metVars, by = c("siteID", "reference_time","value_time")) %>%
               left_join(rollW_qVars,by = c("siteID", "reference_time","value_time")) %>%
               left_join(lag_qVars, c("siteID", "reference_time","value_time")) %>%
               left_join(wl_features, by = c("siteID", "reference_time")) %>%
               left_join(snow_features, by = c("siteID", "reference_time")) %>%
               left_join(catch_atts, by = "siteID") %>%
               left_join(q_obs, by = c("siteID", "value_time")) %>%
               relocate(q_nwm_mr, .after = last_col()) %>%
               relocate(qobs_cms, .after = last_col()) %>%
               relocate(siteID, .before = reference_time) %>%
               arrange(siteID, reference_time, value_time)

# NOTE: Clean the db only for single case
if (testID == "1wq"){
       input_db <- input_db %>% select(-all_of(catch_atts_list))
}

#======================
# Save final dataset
#======================
write.csv(input_db,file = paste0(savePath,"ml_input_db_",testID,"_",test_no,".csv"), row.names=FALSE)
save(input_db, file = paste0(savePath,"ml_input_db_",testID,"_",test_no,".Rdata"))
write_parquet(input_db, paste0(savePath,"ml_input_db_",testID,"_",test_no,".parquet"))

#*************************************
# Adding Q_error (nwm-obs)
#*************************************
# NOTE: this option is to predict the error instead of Q
input_db <- input_db %>% mutate(q_error = qobs_cms - q_nwm_mr)

#======================
# Save final dataset
#======================
write.csv(input_db,file = paste0(savePath,"ml_input_db_",testID,"_",test_no,"_e.csv"), row.names=FALSE)
save(input_db, file = paste0(savePath,"ml_input_db_",testID,"_",test_no,"_e.Rdata"))
write_parquet(input_db, paste0(savePath,"ml_input_db_",testID,"_",test_no,"_e.parquet"))

