#:::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Join all meteorologicall rolling windows prepared
# separatedly with the following script
# 1_a_rolling_windows_metVars_v4.R
#:::::::::::::::::::::::::::::::::::::::::::::::::::

library(dplyr)
library(tidyverse)

source <- "/netfiles/ciroh/mmorales/"
#source <- "Y:/mmorales/"
dataPath <- paste0(source,"NWM_forecasts/NWM_mlCorrection/input_features/")

#===================================
# Read and join rolling windows
#===================================
testID <- "wq" #"1wq" #"all"

filesList <- list.files(dataPath, pattern = glob2rx("rollW_metVars_wq*"), full.names = TRUE)
results <- vector("list", length(filesList))
i <- 1
for (f in filesList){
    load(f)
    data <- rollW_metVars
    results[[i]] <- data
    i <- i + 1
    rm(rollW_metVars)
}

rollW_metVars <- results %>%
                 reduce(full_join, by = c("siteID", "reference_time", "value_time"))

#===================================
# Read and join rolling windows
#===================================
save(rollW_metVars, file = paste0(dataPath,"all_rollW_metVars_",testID,".Rdata"))
