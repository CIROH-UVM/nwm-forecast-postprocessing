#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Script to plot selected events. It includes NWM + ML + Qobs
# These plots will serve to show estimations and double-check
# computed metrics
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

library(lubridate)
library(dplyr)
library(stringr)
library(ggplot2)
library(tidyr)

source <- "/netfiles/ciroh/mmorales/"
#source <- "Y:/mmorales/"
sitesPath <- paste0(source,"NWM_forecasts//InputData/Sites_selection/Final_selection/")
obsPath <- paste0(source,"NWM_forecasts/InputData/processed_data/")
evPath <- paste0(source,"NWM_forecasts/NWM_mlCorrection/output/plots/")
savePath <- paste0(source,"NWM_forecasts/NWM_mlCorrection/output/plots/")

source(paste0(source,"NWM_forecasts/NWM_perfUndst/Codes/R_utils_perfUndst.R"))

# What is the source of the selected events?
#--------------------------------------------
testID <- "wq_2_1b_e"#"wq_2_1_e" #"wq_2_e"#"wq_2"#"wq_e" #"1wq" #It was test_no in 1_process_Qevents_metrics_ML.R
ml_frcstStrt <- as.POSIXct("2022-06-30 23:59:59",format = "%Y-%m-%d %H:%M:%S",tz="UTC")

#========================================
# Loading selected sites
#========================================
load(paste0(paste0(sitesPath,"selFltr_usgs_sites_NE.Rdata")))
dbSites <- usgs_sites_fltr %>% rename("siteID" = "site_no")

#========================================
# Loading observations
#========================================
load(paste0(obsPath,"USGS_Q_Montane_NE_hourly.Rdata"))
#NOTE: Prepared in G:\My Drive\CIROH\Codes\NWM_forecasts\Final_ProjectSecondPart\Prepare_Qobs.R

evalStart <- as.POSIXct("2019-01-01 00:00:00",format = "%Y-%m-%d %H:%M:%S",tz="UTC")
q_obs <- subset(usgs_hourly,siteID %in% dbSites$siteID & dateTime >= evalStart)

# Populate missing values
q_obs <- q_obs %>%
           group_by(siteID) %>%
           complete(dateTime = seq(min(dateTime), max(dateTime), by="hour")) %>%
           select(-qobs_cfs) %>%
           rename("value_time" = "dateTime") %>%
           as.data.frame()

#========================================
# NWM forecast + USGS obs.
#========================================
load(paste0(evPath,"event_metrics/ml_mr_evs_montane_",testID,".Rdata"))
head(mlEvs)

#=================================
# Add range of hours before peak
#=================================
# Only for testing, delete later
dataset <- mlEvs
window <- 50

ml_evsRange <- add_rangeh_bfrpeak(dataset = mlEvs,window = 50)

#====================================
# Select only the times of interest
#====================================
sel_times <- c(48,36,24,12,6)
ml_mr_sel <- subset(ml_evsRange,rangeHr_bfrPeak %in% sel_times) %>%
              select(-t_beforePeak,-rangeHr_bfrPeak,-lead_time)

#=============================
# Prepare final data to plot
#=============================
nwm_forecast <- ml_mr_sel %>%
                filter(value_time >= ml_frcstStrt)

#==================
# Plots
#==================
# Replace configuration names
nwm_forecast$configuration_name[nwm_forecast$configuration_name == "medium_range_mem1"] <- "Medium-Range member 1"
nwm_forecast$configuration_name[grepl("ML", nwm_forecast$configuration_name)] <- "ML"

# Create a dataframe with begining and end per reference time
#-------------------------------------------------------------
temp1 <- nwm_forecast %>% group_by(siteID,reference_time,configuration_name) %>% slice(which.max(value_time)) %>% as.data.frame()
temp1$limit <- "Max_time"
temp2 <- nwm_forecast %>% group_by(siteID,reference_time,configuration_name) %>% slice(which.min(value_time)) %>% as.data.frame()
temp2$limit <- "Min_time"
#temp2$value_time <- temp2$reference_time

limit_times <- rbind(temp1,temp2)

# Plots events per site
#------------------------
for (site in unique(nwm_forecast$siteID)){

       df_sub1 <- nwm_forecast %>%
                 filter(siteID == site)

  for (i in unique(df_sub1$event_id)){

    df_sub <- df_sub1 %>%
              filter(event_id == i)# &
              #configuration_name == "Medium-Range member 1")
              #configuration_name == "ML_Test10_5")

    gg1 <- ggplot()+
         geom_line(data = df_sub, aes(x = value_time, y = qmod_cms,
          group = interaction(reference_time,configuration_name),
          color = configuration_name),linewidth = 0.2)+
         geom_point(data = subset(limit_times,event_id == i & siteID == site & limit == "Min_time"),
         aes(x = value_time, y = qmod_cms, color = configuration_name),size = 0.9)+
         geom_line(data = subset(df_sub,event_id == i & siteID == site), aes(x = value_time, y = qobs_cms),color = "black",linewidth = 0.3)+
      scale_color_manual(values = c("Medium-Range member 1" = "deepskyblue2",
                                    "ML" = "salmon2")) +
       xlab("Date (UTC)") + ylab("Streamflow (cms)") +
       ggtitle(paste(testID,"-","Site:",site,"- Event:",i)) +
       scale_x_datetime(date_labels ="%b %d\n%Y",date_breaks = "1 day") +
       #scale_x_datetime(date_labels ="%b %d %Y",date_breaks = "2 day") +
       #facet_wrap(~configuration_name,scales="free") +
       theme_classic() + theme(plot.title = element_text(size = 12),
                        legend.title = element_blank(),
                        legend.position = "bottom",
                        #legend.justification = c(0.65, 0.010),
                        #legend.position = c(0.65, 0.010),
                        legend.direction="horizontal",
                        legend.text = element_text(size = 11),
                        axis.text= element_text(size=10),
                        axis.title= element_text(size=12),
                        strip.text = element_text(size=4),
                        plot.margin = unit(c(0.07, 0.15, 0.02, 0.02), "in")) # Top, Right, Bottom, Left margins
      #theme(axis.text.x = element_text(angle = 30, hjust = 1))

    # Specify the path to the directory you want to create
    new_dir_path <- paste0(savePath,"per_site/",testID,"/")

    # Check if the directory exists
    if (!dir.exists(new_dir_path)) {
      # If it doesn't exist, create it
      dir.create(new_dir_path, recursive = TRUE)
    }

ggsave(gg1, filename = paste0(new_dir_path,"event_",i,"_",site,"_",testID,".png"), width = 6, height = 4)

}
}

# Plot - facet_wrap per hour in the ref time
#----------------------------------------------
data_process <- subset(ml_evsRange,rangeHr_bfrPeak %in% sel_times)
data_process$rangeHr_bfrPeak <- as.numeric(as.character(data_process$rangeHr_bfrPeak))
data_process$hour <- hour(data_process$reference_time)
# Replace configuration names
data_process$configuration_name[data_process$configuration_name == "medium_range_mem1"] <- "Medium-Range member 1"
data_process$configuration_name[grepl("ML", data_process$configuration_name)] <- "ML"

for (site in unique(nwm_forecast$siteID)){

  df_sub1 <- data_process %>%
             filter(siteID == site)

  for (i in unique(df_sub1$event_id)){

    df_sub <- df_sub1 %>%
              filter(event_id == i)

    temp <- data.frame(rangeHr_bfrPeak = c(48,36,24,12,6))
    df_obs <- subset(q_obs, siteID == site & value_time >= min(df_sub$reference_time) & value_time <= max(df_sub$value_time))
    # Repeat same Qobs data per range
    df_obs <- merge(df_obs,temp)

    df_limits <- subset(limit_times,event_id == i & siteID == site & limit == "Min_time")
    df_limits$rangeHr_bfrPeak <- df_sub[match(df_limits$reference_time, df_sub$reference_time),match("rangeHr_bfrPeak",names(df_sub))]

    gg1 <- ggplot()+
           geom_line(data = df_sub, aes(x = value_time, y = qmod_cms,
                                        group = interaction(reference_time,configuration_name),
                                        color = configuration_name),linewidth = 0.2)+
           geom_point(data = df_limits, aes(x = value_time, y = qmod_cms, color = configuration_name),size = 0.9)+
    geom_line(data = df_obs, aes(x = value_time, y = qobs_cms),color = "black",linewidth = 0.3)+
    scale_color_manual(values = c("Medium-Range member 1" = "deepskyblue2",
                                "ML" = "salmon2")) +
xlab("Date (UTC)") + ylab("Streamflow (cms)") +
ggtitle(paste(testID,"-","Site:",site,"- Event:",i)) +
facet_wrap(~factor(rangeHr_bfrPeak,levels=c(48,36,24,12,6))) +
scale_x_datetime(date_labels ="%b %d\n%Y",date_breaks = "1 day") +
#scale_x_datetime(date_labels ="%b %d %Y",date_breaks = "2 day") +
#scale_x_datetime(date_labels ="%Y-%m-%d") +
theme_classic() + theme(plot.title = element_text(size = 10),
                        legend.title = element_blank(),
                        #legend.position = "bottom",
                        legend.justification = c(0.95, 0.15),
                        legend.position = c(0.95, 0.15),
                        #legend.direction="horizontal",
                        legend.text = element_text(size = 8),
                        axis.text= element_text(size=7),
                        axis.title= element_text(size=9),
                        #axis.title = element_blank(),
                        strip.text = element_text(size=6),
                        panel.spacing.x = unit(4, "mm"),
                        plot.margin = unit(c(0.07, 0.15, 0.02, 0.02), "in")) # Top, Right, Bottom, Left margins

# Specify the path to the directory you want to create
new_dir_path <- paste0(savePath,"per_reft/",testID,"/")

# Check if the directory exists
if (!dir.exists(new_dir_path)) {
  # If it doesn't exist, create it
  dir.create(new_dir_path, recursive = TRUE)
}

ggsave(gg1, filename = paste0(new_dir_path,"event_",i,"_",site,"_",testID,".png"), width = 7.5, height = 3.5)

  }
}
