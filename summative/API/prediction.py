import io
import os
from typing import Any

import joblib
import pandas as pd
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field
from sklearn.linear_model import LinearRegression
from sklearn.preprocessing import StandardScaler


THIS_DIR = os.path.dirname(os.path.abspath(__file__))

# Keep the model artifact location consistent with the training notebook/script.
# Training saved: "outputs/best_aqi_model.pkl" under `summative/linear_regression/`.
MODEL_PATH = os.path.normpath(
    os.path.join(THIS_DIR, "..", "linear_regression", "outputs", "best_aqi_model.pkl")
)


def _load_artifact() -> dict[str, Any]:
    # Try a few likely locations, since the notebook may have been run from
    # a different working directory (which affects relative "outputs/..." paths).
    repo_root = os.path.normpath(os.path.join(THIS_DIR, "..", ".."))
    candidates = [
        MODEL_PATH,
        os.path.normpath(os.path.join(repo_root, "outputs", "best_aqi_model.pkl")),
        os.path.normpath(os.path.join(os.getcwd(), "outputs", "best_aqi_model.pkl")),
    ]

    artifact_path = next((p for p in candidates if os.path.exists(p)), None)
    if artifact_path is None:
        raise FileNotFoundError(
            "Model artifact not found. Tried: "
            + ", ".join([repr(p) for p in candidates])
            + ". Run retraining first (or train the model)."
        )

    artifact = joblib.load(artifact_path)
    required = {"model", "scaler", "features"}
    missing = required - set(artifact.keys())
    if missing:
        raise ValueError(f"Model artifact is missing keys: {sorted(missing)}")
    return artifact


def _predict_from_payload(payload: "PredictionRequest") -> float:
    artifact = _load_artifact()
    model = artifact["model"]
    scaler = artifact["scaler"]
    expected_features = artifact["features"]

    row = payload.to_feature_dict()
    if set(expected_features) != set(row.keys()):
        raise HTTPException(
            status_code=400,
            detail=(
                "Incoming features do not match trained model features. "
                f"Expected {expected_features}."
            ),
        )

    X_df = pd.DataFrame([row])[expected_features]
    X_scaled = scaler.transform(X_df.values)
    pred = model.predict(X_scaled)[0]
    return float(pred)


def _retrain_from_dataframe(df: pd.DataFrame) -> dict[str, Any]:
    required_cols = {
        "PM2.5",
        "PM10",
        "NO",
        "NO2",
        "NH3",
        "SO2",
        "CO",
        "O3",
        "Benzene",
        "City_encoded",
        "AQI",
    }
    missing = required_cols - set(df.columns)
    if missing:
        raise HTTPException(
            status_code=400,
            detail=f"Missing required columns for retraining: {sorted(missing)}",
        )

    model_df = df[list(required_cols)].copy()
    model_df = model_df.apply(pd.to_numeric, errors="coerce").dropna()
    if model_df.empty:
        raise HTTPException(
            status_code=400,
            detail="No usable rows after numeric conversion and null filtering.",
        )

    features = [
        "PM2.5",
        "PM10",
        "NO",
        "NO2",
        "NH3",
        "SO2",
        "CO",
        "O3",
        "Benzene",
        "City_encoded",
    ]
    X = model_df[features].values
    y = model_df["AQI"].values

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    model = LinearRegression()
    model.fit(X_scaled, y)

    os.makedirs(os.path.dirname(MODEL_PATH), exist_ok=True)
    joblib.dump({"model": model, "scaler": scaler, "features": features}, MODEL_PATH)

    return {
        "message": "Model retrained and artifact updated.",
        "rows_used": int(model_df.shape[0]),
        "features": features,
        "artifact_path": MODEL_PATH,
    }


class PredictionRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    pm25: float = Field(..., alias="PM2.5", ge=0.0, le=1000.0)
    pm10: float = Field(..., alias="PM10", ge=0.0, le=1000.0)
    no: float = Field(..., alias="NO", ge=0.0, le=500.0)
    no2: float = Field(..., alias="NO2", ge=0.0, le=500.0)
    nh3: float = Field(..., alias="NH3", ge=0.0, le=500.0)
    so2: float = Field(..., alias="SO2", ge=0.0, le=500.0)
    co: float = Field(..., alias="CO", ge=0.0, le=100.0)
    o3: float = Field(..., alias="O3", ge=0.0, le=500.0)
    benzene: float = Field(..., alias="Benzene", ge=0.0, le=200.0)
    city_encoded: float = Field(..., alias="City_encoded", ge=1.0, le=100.0)

    def to_feature_dict(self) -> dict[str, float]:
        return {
            "PM2.5": float(self.pm25),
            "PM10": float(self.pm10),
            "NO": float(self.no),
            "NO2": float(self.no2),
            "NH3": float(self.nh3),
            "SO2": float(self.so2),
            "CO": float(self.co),
            "O3": float(self.o3),
            "Benzene": float(self.benzene),
            "City_encoded": float(self.city_encoded),
        }


class StreamRecord(BaseModel):
    # Kept as PM2_5 for valid JSON key naming; mapped to "PM2.5" for the model.
    PM2_5: float = Field(..., ge=0.0, le=1000.0, description="Maps to PM2.5")
    PM10: float = Field(..., ge=0.0, le=1000.0)
    NO: float = Field(..., ge=0.0, le=500.0)
    NO2: float = Field(..., ge=0.0, le=500.0)
    NH3: float = Field(..., ge=0.0, le=500.0)
    SO2: float = Field(..., ge=0.0, le=500.0)
    CO: float = Field(..., ge=0.0, le=100.0)
    O3: float = Field(..., ge=0.0, le=500.0)
    Benzene: float = Field(..., ge=0.0, le=200.0)
    City_encoded: float = Field(..., ge=1.0, le=100.0)
    AQI: float = Field(..., ge=0.0, le=1000.0)

    def to_row(self) -> dict[str, float]:
        return {
            "PM2.5": self.PM2_5,
            "PM10": self.PM10,
            "NO": self.NO,
            "NO2": self.NO2,
            "NH3": self.NH3,
            "SO2": self.SO2,
            "CO": self.CO,
            "O3": self.O3,
            "Benzene": self.Benzene,
            "City_encoded": self.City_encoded,
            "AQI": self.AQI,
        }


class StreamRetrainRequest(BaseModel):
    records: list[StreamRecord] = Field(..., min_length=10)


app = FastAPI(
    title="AQI Linear Regression API",
    description="Predict AQI and retrain linear regression model.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def health_check() -> dict[str, str]:
    return {"status": "ok", "docs": "/docs"}


@app.post("/predict")
def predict(payload: PredictionRequest) -> dict[str, float]:
    prediction = _predict_from_payload(payload)
    return {"predicted_aqi": round(prediction, 4)}


@app.post("/retrain/upload")
async def retrain_upload(file: UploadFile = File(...)) -> dict[str, Any]:
    if not file.filename.lower().endswith(".csv"):
        raise HTTPException(status_code=400, detail="Only CSV uploads are supported.")

    content = await file.read()
    try:
        df = pd.read_csv(io.BytesIO(content))
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Invalid CSV file: {exc}") from exc

    return _retrain_from_dataframe(df)


@app.post("/retrain/stream")
def retrain_stream(payload: StreamRetrainRequest) -> dict[str, Any]:
    rows = [r.to_row() for r in payload.records]
    df = pd.DataFrame(rows)
    return _retrain_from_dataframe(df)

