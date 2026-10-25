#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Process AnA Q and forcings from the NWM
# Output in its original version but saved as Rdata with only the
# information we need
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

#library(yaml)
library(dplyr)
library(tidyr)
library(tidyverse)
library(lubridate)
library(stringr)
library(arrow)
#library(data.table)
#library(future.apply)

source <- "Y:/mmorales"
#source <- "/netfiles/ciroh/mmorales"
mainPath <- paste0(source,"/NWM_forecasts/InputData/")
nwmPath <- paste0(mainPath,"processed_data/nwm_forecast/")
sitesPath <- paste0(mainPath,"/Sites_selection/Final_selection/")


##***************************************
## Functions
##***************************************
# Function to read NWM AnA forcings
#-------------------------------------
read_ana_frc <- function(fname,varname,dbSites){
  table <- open_dataset(fname)
  # Load only what we need to save memory
  filtered <- table %>%
              mutate(siteID = sub(".*-", "", location_id)) %>%
              select(value, reference_time, location_id, siteID,
                     value_time,configuration_name,variable_name) %>%
              collect()

  nwm_ana_frc <- subset(filtered, siteID %in% unique(dbSites$site_no))

  # Let's delete the duplicated rows.
  nwm_ana_frc <- nwm_ana_frc %>% distinct(.keep_all = TRUE) %>%
                 arrange(siteID,reference_time,value_time)

  return(as.data.frame(nwm_ana_frc))
}

# Function to read NWM MR forcings
#-------------------------------------
read_mr_frc <- function(fname,varname,dbSites){
  table <- open_dataset(fname)
  # Load only what we need to save memory
  filtered <- table %>%
              mutate(siteID = sub(".*-", "", location_id),
                     cycle = hour(reference_time)) %>%
              select(value, reference_time, location_id, siteID,
                     value_time,configuration_name,variable_name) %>%
              collect()

  nwm_mr_frc <- subset(filtered, siteID %in% unique(dbSites$site_no))

  # Let's delete the duplicated rows.
  nwm_mr_frc <- nwm_mr_frc %>% distinct(.keep_all = TRUE) %>%
                 arrange(siteID,reference_time,value_time)

  return(as.data.frame(nwm_mr_frc))
}

# Function to read NWM AnA Q
#-----------------------------
read_ana_q <- function(fname,dbSites){
  table <- open_dataset(fname)
  # Load only what we need to save memory
  filtered <- table %>%
              mutate(comid = sub(".*-", "", location_id),
              nwmVersion = sub("_.*", "", configuration_name),
              #cycle = hour(reference_time)) %>%
              #filter(cycle %in% c(0)) %>%
                     ) %>%
              select(value, reference_time, location_id, comid,
                     value_time,configuration_name,nwmVersion) %>%
              collect()

  nwm_ana <- subset(filtered, comid %in% unique(dbSites$comid))
  # Assign siteID
  nwm_ana$siteID <- dbSites[match(nwm_ana$comid,dbSites$comid),2]

  # Let's delete the duplicated rows.
  nwm_ana <- nwm_ana %>% distinct(.keep_all = TRUE) %>%
          arrange(siteID,reference_time,value_time)
}

## Apply function to AnA
##========================
# Load montante sites in the NE
load(paste0(sitesPath,"selFltr_usgs_sites_NE.Rdata"))
dbSites <- usgs_sites_fltr

# Apply to streamflow
#----------------------
configurations <- c("analysis_assim","analysis_assim_extend","analysis_assim_extend_no_da","analysis_assim_no_da")

for (configuration in configurations){
    print(paste("Processing",configuration))
    fname <- paste0(nwmPath,configuration,"/nwm_",configuration,"_montane.parquet")
    nwm_ana_q <- read_ana_q(fname,dbSites)

    save(nwm_ana_q, file = paste0(nwmPath,configuration,"/nwm_",configuration,"_montane.Rdata"))
    print("Dataset saved...")
}

# Apply to forcings
#----------------------
#configurations <- c("forcing_analysis_assim","forcing_analysis_assim_extend")
#varname <- "RAINRATE"

configurations <- c("forcing_analysis_assim_extend")
varnames <- c("RAINRATE","LWDOWN","SWDOWN","PSFC","Q2D","T2D","U2D","V2D")

for (configuration in configurations){
  for (varname in varnames){
    print(paste("Processing",configuration,",",varname))
    fname <- paste0(nwmPath,configuration,"/",varname,"/nwm_",configuration,"_montane.parquet")
    nwm_ana_frc <- read_ana_frc(fname,varname,dbSites)

    save(nwm_ana_frc, file = paste0(nwmPath,configuration,"/",varname,"/nwm_",configuration,"_montane.Rdata"))
    print("Dataset saved...")
  }
}

## Apply function to MR
##========================
# Apply to forcings
#----------------------
#configurations <- c("forcing_analysis_assim","forcing_analysis_assim_extend")
#varname <- "RAINRATE"

configurations <- c("forcing_medium_range")
varnames <- c("RAINRATE","LWDOWN","SWDOWN","PSFC","Q2D","T2D","U2D","V2D")

for (configuration in configurations){
  for (varname in varnames){
    print(paste("Processing",configuration,",",varname))
    fname <- paste0(nwmPath,configuration,"/",varname,"/nwm_",configuration,"_montane.parquet")
    nwm_mr_frc <- read_mr_frc(fname,varname,dbSites)

    save(nwm_mr_frc, file = paste0(nwmPath,configuration,"/",varname,"/nwm_",configuration,"_montane.Rdata"))
    print("Dataset saved...")
  }
}
