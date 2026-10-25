#:::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Plot error distributions
# for MR member 1 and ML model
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::

library(dplyr)
library(ggplot2)
library(tidyr)
library(stringr)
library(foreach)

source <- "/netfiles/ciroh/mmorales/"
#source <- "Y:/mmorales/"
evPath <- paste0(source,"NWM_forecasts/NWM_mlCorrection/output/plots/")
perfUndstPath <- paste0(source,"NWM_forecasts/NWM_perfUndst/teva_inputs/")
sitesPath <- paste0(source,"NWM_forecasts//InputData/Sites_selection/Final_selection/")
savePath <- paste0(source,"NWM_forecasts/NWM_mlCorrection/output/plots/wq_report/")

source(paste0(source,"NWM_forecasts/NWM_perfUndst/Codes/R_utils_perfUndst.R"))

# When does the ML start the predictions?
#--------------------------------------------
ml_frcstStrt <- as.POSIXct("2022-06-30 23:59:59",format = "%Y-%m-%d %H:%M:%S",tz="UTC")

#========================================
# Loading selected sites
#========================================
load(paste0(paste0(sitesPath,"selFltr_usgs_sites_NE.Rdata")))
dbSites <- usgs_sites_fltr %>% rename("siteID" = "site_no")

#========================================
# Load metrics
#========================================
# ML
filesList <- list.files(paste0(evPath,"event_metrics/"), pattern = glob2rx("ml_mr_metrics_montane_wq_*"), full.names = TRUE)

mlMetrics_all <- foreach (f = filesList, .combine = rbind.data.frame) %do% {
    load(f)
    temp <- mlMetrics
    temp$configuration_name <- str_match(basename(f), "_(wq[^.]*)\\.Rdata$")[,2]
    #paste0(str_split_i(basename(f), '_', 5),"_",
    #                                  gsub("[^0-9]", "", str_split_i(basename(f), '_', 6)))
    mlMetrics_all <- temp
}

# Add a temporary identifier
mlMetrics_all$tempTag <- paste0(mlMetrics_all$siteID,"_",mlMetrics_all$event_id)

# NWM_forecasts
load(paste0(perfUndstPath,"event_metrics/aep/nwm_mr_metrics_montane.Rdata"))
#head(mrMetrics)
mrMetrics <- mrMetrics %>% rename("value_time_mod" = "value_time_nwm",
                                  "qmod_cms" = "qnwm_cms") %>%
             mutate(configuration_name = "NWM",
                    tempTag = paste0(siteID,"_",event_id)) %>%
             # Select to macth with ML sites
             filter(tempTag %in% unique(mlMetrics_all$tempTag)) %>%
             select(-tempTag)

# Delete temporary tag
mlMetrics_all <- mlMetrics_all %>% select(-tempTag)

# Join all the sources
model_metrics <- rbind.data.frame(mlMetrics_all,mrMetrics)

#========================================
# Process medium-range
#========================================
# Add range of hours before peak
#----------------------------------
mr_df <- add_rangeh_bfrpeak(dataset = model_metrics,window = 50)

# Select only the times of interest
#-----------------------------------
sel_times <- c(48,36,24,12,6)
nwm_mr_sel <- subset(mr_df,rangeHr_bfrPeak %in% sel_times)

# Adding peak time error in hours (not seconds)
nwm_mr_sel$qpt_error_hr <- as.numeric(nwm_mr_sel$qpt_error)/3600

# NOTE:
# qpt_error = Qpt_mod - Qpt_obs

# Adding identifiers to clasify performance
#-------------------------------------------
nwm_mr_sel$month <- month.abb[month(nwm_mr_sel$value_time_obs)]

data_proces <- add_nwm_version(dataset = nwm_mr_sel)

data_proces <- data_proces %>%
               select(siteID,event_id,rangeHr_bfrPeak,nwmVersion,month,qpm_error,
                      Perc_qpm_error,qpm_normerror,qpt_error_hr,Nse,configuration_name) %>%
                gather(metric, value, qpm_error:Nse)

data_proces$rangeHr_bfrPeak <- as.character(data_proces$rangeHr_bfrPeak)

# clean outliers
#-----------------
df_cleaned <- data_proces %>%
              group_by(month,siteID,metric,configuration_name) %>%
              mutate(value_cleaned = ifelse(value > quantile(value,0.75,na.rm=T)+1.5*IQR(value,na.rm=T) |
                                            value < quantile(value,0.25,na.rm=T)-1.5*IQR(value,na.rm=T),NA,value)) %>%
              as.data.frame()

#========================
# Compute mean values
#========================
data_proces2 <- add_nwm_version(dataset = nwm_mr_sel)
data_proces2 <- data_proces2 %>%
               select(siteID,event_id,rangeHr_bfrPeak,nwmVersion,month,qpm_error,
                      Perc_qpm_error,qpm_normerror,qpt_error_hr,Nse,configuration_name)

data_proces2$rangeHr_bfrPeak <- as.character(data_proces2$rangeHr_bfrPeak)

# PER SITE (for spatial distribution)
#--------------------------------------
# Per tbefore peak, configuration and site
mean_siteRng <- data_proces2 %>%
  group_by(siteID, rangeHr_bfrPeak,configuration_name) %>%
  summarise(
    mean_Perc_qpm_error = mean(Perc_qpm_error),
    mean_qpt_error_hr = mean(qpt_error_hr),
    mean_nse = mean(Nse),.groups = "drop"
  )

# Per tbefore peak, configuration, site and NWM version
mean_siteRngV <- data_proces2 %>%
  group_by(siteID, rangeHr_bfrPeak,nwmVersion,configuration_name) %>%
  summarise(
    mean_Perc_qpm_error = mean(Perc_qpm_error),
    mean_qpt_error_hr = mean(qpt_error_hr),
    mean_nse = mean(Nse),.groups = "drop"
  )

# GENERAL (consifering all sites together) - General and quick assessment
#-------------------------------------------------------------------------
mean_RngConf <- data_proces2 %>%
                group_by(rangeHr_bfrPeak,configuration_name,month) %>%
                summarise(
                  mean_Perc_qpm_error = mean(Perc_qpm_error),
                  mean_qpt_error_hr = mean(qpt_error_hr),
                  mean_nse = mean(Nse),.groups = "drop"
                )

mean_RngConfV <- data_proces2 %>%
                group_by(rangeHr_bfrPeak,nwmVersion,configuration_name,month) %>%
                summarise(
                  mean_Perc_qpm_error = mean(Perc_qpm_error),
                  mean_qpt_error_hr = mean(qpt_error_hr),
                  mean_nse = mean(Nse),.groups = "drop"
                )

# Add lat/lon
mean_siteRng <- merge(mean_siteRng,dbSites[,c("siteID","dec_lat_va","dec_long_va","drain_area_va_sqmi")],by=c("siteID"))
mean_siteRngV <- merge(mean_siteRngV,dbSites[,c("siteID","dec_lat_va","dec_long_va","drain_area_va_sqmi")],by=c("siteID"))

# Export to plot in ArcGis
#write.csv(mean_siteRng, file = paste0(evPath,"event_metrics/mean_siteRng_MLnwm_montane.csv"), row.names=FALSE)
#write.csv(mean_siteRngV, file = paste0(evPath,"event_metrics/mean_siteRngV_MLnwm_montane.csv"), row.names=FALSE)

# Select the best performing models
sel_tests <- c("NWM","wq_1","wq_e","wq_2_b_e")#,"wq_2_e")
df_cleaned <- df_cleaned %>% filter(configuration_name %in% sel_tests)

#====================
# Plot distributions
#====================
# Improve names for legend
df_cleaned$metric[df_cleaned$metric == "qpm_error"] <- "Qpm error (cms)"
df_cleaned$metric[df_cleaned$metric == "Perc_qpm_error"] <- "Qp error (%)"
df_cleaned$metric[df_cleaned$metric == "qpm_normerror"] <- "Normalized Qp error"
df_cleaned$metric[df_cleaned$metric == "qpt_error_hr"] <- "Qp time error (hours)"
df_cleaned$metric[df_cleaned$metric == "Nse"] <- "NSE"
df_cleaned$configuration_name[df_cleaned$configuration_name == "wq_1"] <- "ML [target Q]"
df_cleaned$configuration_name[df_cleaned$configuration_name == "wq_e"] <- "ML [target error]"
df_cleaned$configuration_name[df_cleaned$configuration_name == "wq_2_b_e"] <- "ML [target error] v2"

test_order <- c("NWM", "ML [target Q]","ML [target error]","ML [target error] v2")

my_theme <- theme_bw() + theme(legend.position="bottom",
                               legend.title=element_blank(),
                               axis.text= element_text(size=10),
                               axis.title= element_text(size=11),
                               legend.text=element_text(size=9),
                               plot.tag = element_text(size=10),
                               #axis.text.x = element_text(size=7,angle = 60, hjust = 1),
                               panel.grid.minor = element_blank(),
                               panel.grid.major.x = element_blank(),
                               strip.background = element_blank(),
                               strip.text = element_blank(),
                               legend.key.height=grid::unit(0.3,"cm"),
                               legend.spacing.y = unit(0.01, "cm"),
                               legend.margin=margin(0,0,4,0),
                               legend.box.margin=margin(t=-4,r=14,b=-3,l=-10))

#-----------------------------------------------------------------------
# All the times before peak and including all versios (NO OUTLIERS)
#-----------------------------------------------------------------------
tbrpeak_levels <- c("48","36","24","12","6")

sel_metric <- "Qp error (%)"
plot_name <- gsub("[^[:alpha:]]", "", sel_metric)
gg1 <- ggplot(data = subset(df_cleaned,metric == sel_metric),
              aes(x = factor(rangeHr_bfrPeak, levels = tbrpeak_levels),y = value_cleaned,
                   fill = factor(configuration_name,levels = test_order))) +
       geom_boxplot(colour = "gray52",alpha = 0.3,lwd=.2,outlier.size=0.1,outlier.alpha = 0.5) +
        geom_hline(yintercept = 0, color = "firebrick4",lwd=.3) +
       stat_summary(fun = mean, geom = "point", aes(group = factor(configuration_name,levels = test_order)),
                    position = position_dodge(width = 0.75),
                    shape = 23, size = 0.8, fill = "red") +
       #scale_fill_brewer(palette="Set1") +
       xlab("Time before peak (hour)") + ylab(sel_metric) + my_theme

ggsave(gg1, filename = paste0(savePath,plot_name,"_nwmML_gral.png"), width = 6, height = 3)

sel_metric <- "NSE"
plot_name <- gsub("[^[:alpha:]]", "", sel_metric)
gg1 <- ggplot(data = subset(df_cleaned,metric == sel_metric),
              aes(x = factor(rangeHr_bfrPeak, levels = tbrpeak_levels),y = value_cleaned,
                  fill = factor(configuration_name,levels = test_order))) +
       geom_boxplot(colour = "gray52",alpha = 0.3,lwd=.2,outlier.size=0.1,outlier.alpha = 0.5) +
       geom_hline(yintercept = 0, color = "firebrick4",lwd=.3) +
       stat_summary(fun = mean, geom = "point", aes(group = factor(configuration_name,levels = test_order)),
                    position = position_dodge(width = 0.75),
                    shape = 23, size = 0.8, fill = "red") +
       #scale_fill_brewer(palette="Set1") +
       xlab("Time before peak (hour)") + ylab(sel_metric) + my_theme

ggsave(gg1, filename = paste0(savePath,plot_name,"_nwmML_gral.png"), width = 6, height = 3)

sel_metric <- "Qp time error (hours)"
plot_name <- gsub("[^[:alpha:]]", "", sel_metric)
gg1 <- ggplot(data = subset(df_cleaned,metric == sel_metric),
              aes(x = factor(rangeHr_bfrPeak, levels = tbrpeak_levels),y = value_cleaned,
                  fill = factor(configuration_name,levels = test_order))) +
       geom_boxplot(colour = "gray52",alpha = 0.3,lwd=.2,outlier.size=0.1,outlier.alpha = 0.5) +
       geom_hline(yintercept = 0, color = "firebrick4",lwd=.3) +
       stat_summary(fun = mean, geom = "point", aes(group = factor(configuration_name,levels = test_order)),
                    position = position_dodge(width = 0.75),
                    shape = 23, size = 0.8, fill = "red") +
       #scale_fill_brewer(palette="Set1") +
       xlab("Time before peak (hour)") + ylab(sel_metric) + my_theme

ggsave(gg1, filename = paste0(savePath,plot_name,"_nwmML_gral.png"), width = 6, height = 3)

# Distributions (density plots) - For comparisson
#--------------------------------------------------
sel_metric <- c("Qp error (%)","NSE","Qp time error (hours)")
times_sel <- c("48","24","6")

for (m in sel_metric){
    plot_name <- gsub("[^[:alpha:]]", "", m)

    gg2 <- ggplot(subset(df_cleaned,metric == m & rangeHr_bfrPeak %in% times_sel),
                  aes(x=value, color = configuration_name, fill = configuration_name)) +
           geom_density(alpha = 0.2) + #facet_wrap(~metric,scales = "free") +
           facet_wrap(~factor(rangeHr_bfrPeak, levels = tbrpeak_levels),scales = "free") +
    #ggh4x::facet_grid2(rangeHr_beforePeak ~ metric,scales = "free", independent = "y") +
    #scale_fill_brewer(palette="Set1") +
    labs(title = m, y = "Density") +
    theme_minimal() + #theme_bw() +
    theme(legend.position="bottom",
          plot.title = element_text(size = 11),
          axis.title = element_text(size=11),
          axis.text = element_text(size=10),
          strip.text = element_text(size = 10),
          #legend.title = element_text(size=9),
          legend.title = element_blank(),
          legend.text = element_text(size=8),
          legend.key.height=grid::unit(0.3,"cm"),
          legend.box.margin=margin(t=-6,r=14,b=-3,l=-10))

  ggsave(gg2, filename = paste0(savePath,"DensPlot_",plot_name,"_nwmML_gral.png"),width = 5.7, height = 3.2)

  }

#--------------------------------------------------------------
# All the times before peak divided by month and version
#--------------------------------------------------------------
sel_metric <- c("Qp error (%)","NSE","Qp time error (hours)")
times_sel <- c("48","24","6")
factor_months <- c("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")

data_proces <- mean_RngConf %>%
               gather(metric, value, mean_Perc_qpm_error:mean_nse)

# Improve names for legend
data_proces$metric[data_proces$metric == "mean_Perc_qpm_error"] <- "Mean Qp error (%)"
data_proces$metric[data_proces$metric == "mean_qpt_error_hr"] <- "Mean Qp time error (hours)"
data_proces$metric[data_proces$metric == "mean_nse"] <- "Mean NSE"

for (t in times_sel){

  gg <- ggplot(data = subset(data_proces,rangeHr_bfrPeak == t),
               aes(x = factor(month, levels=factor_months), y = value,
                   fill = configuration_name)) +
        geom_bar(position = "dodge", stat="identity", alpha=0.5,width = 0.5) +
        ggtitle(paste("Time before peak:",t,"hours")) +
  #scale_fill_manual(values = c("NWM - v2.1" = "dodgerblue","LightGBM" = "tomato2","LightGBM_WL" = "forestgreen")) +
  #scale_fill_brewer(palette="Set1") +
facet_wrap(~metric, scales = "free_y") +
theme_bw() +
theme(legend.position="bottom",
      plot.title = element_text(size = 11),
      axis.title = element_blank(),
      axis.text = element_text(size=10),
      strip.text = element_text(size = 10),
      #legend.title = element_text(size=9),
      legend.title = element_blank(),
      legend.text = element_text(size=8),
      legend.key.height = grid::unit(0.3,"cm"),
      legend.box.margin = margin(t=-6,r=14,b=-3,l=-10))


ggsave(gg, filename = paste0(savePath,"MeanBars_tbfrPeak_",t,"_nwmML_gral.png"),width = 9.5, height = 4)
}

gg <- ggplot(data = subset(data_proces,rangeHr_bfrPeak %in% times_sel),
             aes(x = factor(month, levels=factor_months), y = value,
                 fill = configuration_name)) +
      geom_bar(position = "dodge", stat="identity", alpha=0.5,width = 0.5) +
      #scale_fill_manual(values = c("NWM - v2.1" = "dodgerblue","LightGBM" = "tomato2","LightGBM_WL" = "forestgreen")) +
#scale_fill_brewer(palette="Set1") +
#facet_wrap(~metric, scales = "free_y") +
ggh4x::facet_grid2(factor(rangeHr_bfrPeak, levels = times_sel)~ metric,scales = "free", independent = "y") +
theme_bw() +
theme(legend.position="bottom",
      plot.title = element_text(size = 11),
      axis.title = element_blank(),
      axis.text = element_text(size=10),
      strip.text = element_text(size = 10),
      #legend.title = element_text(size=9),
      legend.title = element_blank(),
      legend.text = element_text(size=8),
      legend.key.height = grid::unit(0.3,"cm"),
      legend.box.margin = margin(t=-6,r=14,b=-3,l=-10))

ggsave(gg, filename = paste0(savePath,"MeanBars_All_tbfrPeak_nwmML_gral.png"),width = 12.5, height = 4)
