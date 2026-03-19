## Mission

Rapid urbanization in cities like Kigali and major Indian urban centers increases the risk of harmful air pollution. This project predicts fine particulate matter and overall air quality levels using environmental and atmospheric variables such as pollutant concentrations (PM2.5, PM10, NO2, SO2, CO, O3), along with derived time information. Accurate short‑term air quality forecasts can help residents and city planners make informed decisions to reduce exposure and manage pollution sources.

## Dataset Description

The dataset contains daily air‑quality measurements for multiple Indian cities, including pollutant concentrations (PM2.5, PM10, NO, NO2, NOx, NH3, CO, SO2, O3, Benzene, Toluene, Xylene) and an aggregated Air Quality Index (AQI). Each row represents one day in a specific city, and the target variable used for modelling in this project is **AQI**, which summarizes overall air‑quality conditions.

**Data Source**

- **Title**: Air Quality Data in India (2015–2020)
- **Author**: rohanrao
- **Link**: https://www.kaggle.com/datasets/rohanrao/air-quality-data-in-india

This dataset is rich in both **volume** (multiple years and cities) and **variety** (many pollutant and city features), making it suitable for a regression task that predicts AQI from pollutant and city‑level variables.

## Exploratory Analysis – Interpretation

- AQI is right‑skewed with occasional extreme pollution days.
- Cities differ systematically in their median AQI, which motivates including a city‑level feature.
- AQI is strongly correlated with PM10, PM2.5 and CO; moderately with NO2 and SO2.
- Some pollutants (NO, NO2, NOx) are highly correlated with each other, so NOx is dropped to reduce redundancy.
- Scatter plots confirm that higher pollutant levels generally correspond to higher AQI.

## Feature Engineering and Preprocessing

- Dropped columns: NOx (multicollinear with NO/NO2), Toluene and Xylene (weak correlation), Year (weak direct relationship to AQI).
- Encoded City as `City_encoded` based on mean city AQI to capture systematic city differences without many one‑hot columns.
- Imputed missing numeric values with the median to be robust to outliers.
- Standardized features with `StandardScaler` so gradient‑descent‑based linear regression converges reliably and features are on a comparable scale.

