# Task 2 - FastAPI Service

This API serves AQI predictions from the best saved linear regression model and supports model retraining from uploaded or streamed data.

## Local run

From the project root:

```bash
pip install -r summative/API/requirements.txt
uvicorn summative.API.prediction:app --reload
```

Swagger UI:

- http://127.0.0.1:8000/docs

## Endpoints

- `POST /predict`
  - Accepts pollutant values and `City_encoded`
  - Enforces numeric data types and realistic value ranges via Pydantic
- `POST /retrain/upload`
  - Upload a CSV file with required columns:
    - `PM2.5`, `PM10`, `NO`, `NO2`, `NH3`, `SO2`, `CO`, `O3`, `Benzene`, `City_encoded`, `AQI`
  - Retrains linear regression and overwrites `outputs/best_aqi_model.pkl`
- `POST /retrain/stream`
  - Accepts streamed records in JSON (`records`) and retrains the model

## Render deployment

1. Push this repository to GitHub.
2. In Render, create a **Web Service** from the repo.
3. Render reads `render.yaml` automatically, or use:
   - Build command: `pip install -r summative/API/requirements.txt`
   - Start command: `uvicorn summative.API.prediction:app --host 0.0.0.0 --port $PORT`
4. After deployment, open:
  - `https://linear-regression-model-cmw6.onrender.com/docs`

Use that `/docs` URL as your public Swagger link for submission.
