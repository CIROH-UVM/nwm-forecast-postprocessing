#---------------------------------------------------------------------------------------
This folder contains all the scripts used to prepare the input database and run the ML
correction model for the NWM medium-range (MR) streamflow forecasts
Scripts are presented in order of execution
#---------------------------------------------------------------------------------------

Path to TEEHR codes and raw data on the VACC
------------------------------------------------
Codes: /gpfs1/pi/aschroth 
Raw data: /scratch/teehr/nwm_forecast_archive_uvm/parquet

*******************
A) Data fetching
*******************
Scripts path: /netfiles/ciroh/mmorales/NWM_forecasts/teehr/ForVACC
Raw parquets path: /netfiles/ciroh/mmorales/NWM_forecasts/teehr/nwm_forecast_archive_uvm/parquet
Processed parquets path: /netfiles/ciroh/mmorales/NWM_forecasts/InputData/processed_data/nwm_forecast

(1) Get raw NWM data
Script: NWM_fetch_forecasts_MRforcings_localCluster_args.py
    	NWM_fetch_forecasts_Q_localCluster_TB.py
Objective: Retrieve NWM Q and forcings with TEEHR at the 151 montane sites
Dependencies: N/A
Input: Basin weights (usgs_basins_to_nwm_grid_weights.uvm151.parquet) 
       site's location (selFltr_usgs_sites_NE.csv)
Output: Raw parquets

(2) Join NWM parquets
Script: /netfiles/ciroh/mmorales/NWM_forecasts/teehr/NWM_fetch_forecasts_MRQ.ipynb
Objective: Join single parquets into one for the full processed period
Dependencies: A1
Input: Single raw parquets generated w/ A1
Output: Joined parquets for full period

*******************
B) Preprocessing
*******************
Scripts path: ./preprocessing/Rscripts
Main output path: /netfiles/ciroh/mmorales/NWM_forecasts/NWM_mlCorrection/final_inputDb/

(1) Filter and prepare NWM data
Script: 0_a_process_nwmAnAs.R
Objective: Process raw NWM AnA, MR Q and forcings retrieved from TEEHR and saves them as Rdata with only
           the information we need.
Dependencies: A2
Input: Raw NWM joined data in a parquet file
Output: Filtered NWM data in Rdata format for the sites of interest.

(2) Compute proportional NWM proportional Q
Script: 0_b_prepare_nwm.R
Objective: Read NWM Q data and compute proportional Q at sites within the same comid
Dependencies: B1
Input: Raw NWM joined data in a parquet file
Output: Filtered NWM data in Rdata format for the sites of interest.

(3) Compute rolling windows for NWM forcings
Script: 1_a_rolling_windows_metVars_v4.R
Objective: Computes rolling windows based on NWM forcings (AnA Ext., AnA, and MR)
	   This is to keep track of antecedent conditions
Dependencies: N/A
Input: Preprocessed NWM Q and forcings
Output: Rolling windows across all sites and ref times
 
(4) Join rolling windows
Script: 1_b_joinall_rolling_windows_metVars.R
Objective: Join all meteorological rolling windows to avoid having multiple files
Dependencies: B3
Input: Separated rolling windows
Output: One single file with all rolling windows

(5) Compute rolling windows for NWM Q
Script: 1_c_rolling_windows_Q_v4.R
Objective: Computes rolling windows based on NWM Q (AnA Ext., AnA |both with DA|, and MR)
Dependencies: B2
Input: NWM Q data
Output: Rolling windows across all sites and ref times. Windows can be hybrid, depending
	on the ref time and data availability

(6) Prepare NWM Q lag features
Script: 2_a_lags_creation_Q_v3.R
Objective: Computes lag features based on NWM Q (AnA Ext., AnA |both with DA|, and MR)
Dependencies: B2
Input: NWM Q data
Output: NWM Q lag features for all sites and ref times. Lags can come from different sources
	depending on the reference time and data availability

(7) Prepare SWE, snow depth and water level lag features
Script: 2_b_lags_creation_snow_wl.R
Objective: Computes lag features based on observed SWE, snow depth (from SNODAS) and water level (USGS)
Dependencies: 
Input: 
Output: Observed lag features for each site, ref time and at the specified lags

(8) Prepares NWM data at forecast time
Script: 3_nwm_metVars_frcstH.R
Objective: Gets the NWM Q and forcings at the forecast time in the format needed for the ML model
Dependencies: B1, B2
Input: Raw NWM Q and forcings
Output: NWM forecast data at forecast time to be corrected

(9) Prepare final input DB
Script: 4_prepare_inputDB.R
Objective: Joins all the pre processed data to create the final input DB for the ML model
Dependencies: All previous scripts
Input: All features created in the previous steps
Output: Final ML input DB

******************
C) ML model
******************
Script path: ./ml_models/lightgbm
Output path: /netfiles/ciroh/mmorales/NWM_forecasts/NWM_mlCorrection/output

Script: ml_lightgbm_Qfrsct_testbed.py
Dependencies: B9
Objective: LightGBM model to improve NWM Q MR forecasts
Input: Input DB
Output: Corrected flows

******************
D) Postprocessing
******************
Scripts path: ./postprocessing

1_process_Qevents_metrics_ML.R
2_plot_events_aep.R
3_plot_errorDistributions_ML_wqReport.R

