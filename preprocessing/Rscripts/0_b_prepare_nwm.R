#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Objective: This code is meant for reading the output parquet
# file that cointains all the NWM data of interest retrieved using TEHHR
# and computes any proportional Q for sites where it is necessary
#
# Dependiencies:
# G:/My Drive/CIROH/Codes/NWM_perfUndst/1a_process_nwmAnAs.R
#
# Created: 8/14/2025
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

library(dplyr)
library(arrow)

#source <- "Y:/mmorales/"
source <- "/netfiles/ciroh/mmorales/"
nwmPath <- paste0(source,"NWM_forecasts/InputData/processed_data/nwm_forecast/")
sitesPath <- paste0(source,"NWM_forecasts/InputData/Sites_selection/Final_selection/")
xtraInfo <- paste0(source,"NWM_forecasts/InputData/Sites_selection/")
savePath <- paste0(source,"NWM_forecasts/NWM_perfUndst/nwm_data/")

# Load sites' information
#===========================
# Load montante sites in the NE
load(paste0(sitesPath,"selFltr_usgs_sites_NE.Rdata"))
dbSites <- usgs_sites_fltr

# Load additional USGS sites information
load(paste0(xtraInfo,"usgs_NHDAttr_FltrSOYrBslope70_NE.Rdata")) # 0.70 basin slope quantile thr
auxDf <- sel_usgsNhdattr

# Add information
dbSites$drain_area_va_sqmi <- auxDf[match(dbSites$site_no, auxDf$site_no),match("drain_area_va_sqmi",names(auxDf))]
dbSites$nhdplus_area_sqmi <- auxDf[match(dbSites$site_no, auxDf$site_no),match("nhdplus_area_sqmi",names(auxDf))]

#========================
# Functions
#========================
# Function to compute NWM proportional Q at sites within the same comid
gets_propQ_nwm <- function(nwmdf,dbSites){
  # We will get the proportion for the basin with the smallest area
  # find repeated comids
  repComids <- subset(dbSites,duplicated(comid))
  sites_wreps <- subset(dbSites, comid %in% repComids$comid)

  nwm_prorr <- c()
  for (i in unique(repComids$comid)){
    temp <- subset(sites_wreps,comid == i)

    bigger <- temp[which.max(temp$drain_area_va_sqmi), ]
    smaller <- temp[which.min(temp$drain_area_va_sqmi), ]
    weight <- smaller$drain_area_va_sqmi/bigger$drain_area_va_sqmi

    tempdf <- subset(nwmdf,comid == i) # This will correspond to the bigger basin
    tempdf2 <- tempdf # This will correspond to the smaller basin (weighted)

    # Replace siteID for the other sites that fall within the same reach
    tempdf$siteID <- bigger$site_no
    tempdf2$siteID <- smaller$site_no

    # Let's compute the NWM Q prorated by the basin area
    tempdf2$value <- weight*(tempdf2$value)

    # Add back to the main database
    df_weight <- rbind(tempdf,tempdf2)

    nwm_prorr <- rbind(nwm_prorr,df_weight)
  }
  return(nwm_prorr)
}

#========================
# AnA (with DA)
#========================
configuration <- "analysis_assim"
load(paste0(nwmPath,configuration,"/nwm_",configuration,"_montane.Rdata"))

# Find duplicated sites in the list of sites and missings in the nwm
#--------------------------------------------------------------------
repComids <- subset(dbSites,duplicated(comid))
sites_wreps <- subset(dbSites, comid %in% repComids$comid)

# Check if there are missing sites
setdiff(unique(dbSites$site_no),unique(nwm_ana_q$siteID))

# Apply function to compute proportional Q on basins within same comid
#-------------------------------------------------------------------------------
nwm_1 <- subset(nwm_ana_q,!(comid %in% repComids$comid))

nwm_weighted <- gets_propQ_nwm(nwmdf=nwm_ana_q,dbSites=dbSites)

# Add weigthed sites to main Dataset
nwm_ana_q <- rbind(nwm_1,nwm_weighted)

# double-check changes
setdiff(unique(dbSites$siteID),unique(nwm_ana_q$siteID))

# Save final dataset
#---------------------
save(nwm_ana_q, file = paste0(savePath,"nwm_",configuration,"_montane.Rdata"))
print("Dataset saved...")

#========================
# AnA Ext. (with DA)
#========================
configuration <- "analysis_assim_extend"
load(paste0(nwmPath,configuration,"/nwm_",configuration,"_montane.Rdata"))

# Find duplicated sites in the list of sites and missings in the nwm
#--------------------------------------------------------------------
repComids <- subset(dbSites,duplicated(comid))
sites_wreps <- subset(dbSites, comid %in% repComids$comid)

# Check if there are missing sites
setdiff(unique(dbSites$site_no),unique(nwm_ana_q$siteID))

# Apply function to compute proportional Q on basins within same comid
#-------------------------------------------------------------------------------
nwm_1 <- subset(nwm_ana_q,!(comid %in% repComids$comid))

nwm_weighted <- gets_propQ_nwm(nwmdf=nwm_ana_q,dbSites=dbSites)

# Add weigthed sites to main Dataset
nwm_ana_q <- rbind(nwm_1,nwm_weighted)

# double-check changes
setdiff(unique(dbSites$siteID),unique(nwm_ana_q$siteID))

# Save final dataset
#---------------------
save(nwm_ana_q, file = paste0(savePath,"nwm_",configuration,"_montane.Rdata"))
print("Dataset saved...")





