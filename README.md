# NWM Forecast Postprocessing

## Overview

This repository contains the workflow for developing and evaluating machine learning (ML) approaches to post-process and improve streamflow forecasts from the NOAA National Water Model (NWM) Medium-Range forecast system.

The project aims to investigate how machine learning techniques can be used to correct forecast errors and improve streamflow prediction performance, to then be coupled with a water quality machine learning forecast model. The repository includes the scripts and supporting configuration needed to prepare input datasets, develop and apply post-processing models, and evaluate their performance.

## Project Workflow

The workflow is organized into the following main stages:

1. **Data preparation:** Prepare and integrate the datasets required for model development.
2. **Model development:** Train and tune machine learning models for streamflow forecast post-processing.
3. **Forecast postprocessing:** Apply trained models to generate corrected streamflow forecasts.
4. **Model evaluation:** Assess model performance and compare post-processed forecasts with the original NWM forecasts and USGS streamflow observations.

## Repository Structure

The repository is organized by workflow stage and model type to facilitate the addition of new postprocessing approaches.

- `preprocessing/`: Scripts for preparing the input dataset for the ML model.
- `ml_models/`: Model-specific scripts for training, tuning, and generating predictions.
- `postprocessing/`: Scripts for postprocessing steps, which include evaluation of ML model performance.

*See the README_scripts.txt for a detailed description of each file in the folders.*

## Notes

This repository is under development. Its organization, documentation, and supported postprocessing approaches may evolve as the workflow expands.
