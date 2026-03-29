# Linear regression — AQI prediction

## Mission and problem

Urban air quality varies sharply by city and pollutant mix. This project predicts **Air Quality Index (AQI)** from pollutant concentrations and a city encoding, using multivariate linear regression on Indian air-quality data. The goal is to support quick, repeatable predictions for coursework assessment and a small mobile demo. A trained model is served over HTTP so inputs can be validated and scored without running the notebook locally.

## Public API (Swagger UI)

Assessments use **Swagger UI** against a **publicly routable** base URL (not `localhost`).

- **Swagger UI:** [https://linear-regression-model-cmw6.onrender.com/docs](https://linear-regression-model-cmw6.onrender.com/docs)
- **Predictions:** `POST /predict` — send pollutant fields and `City_encoded`; the response includes the predicted AQI.

If you redeploy the API, replace the URL above (and the `baseUrl` in the Flutter app) with your new host.

## Demo video (≤ 5 minutes)

- [YouTube demo](https://youtu.be/-M83FQi9424)

## Run the mobile app (Flutter)

**Prerequisites:** [Flutter SDK](https://docs.flutter.dev/get-started/install) installed and on your `PATH`, plus an emulator, simulator, or physical device.

1. Open a terminal at the repository root (or anywhere) and go to the app folder:

   ```bash
   cd summative/FlutterApp
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Point the app at your API (if needed): edit `lib/main.dart` and set `baseUrl` to your deployed FastAPI base URL (no trailing slash), keeping `pathToPredict` as `/predict`.

4. Run on a connected device or emulator:

   ```bash
   flutter run
   ```

5. **Android:** ensure USB debugging is on for a physical device, or start an AVD from Android Studio. **iOS (macOS only):** open the simulator or connect an iPhone and select the device when prompted.

## Repository layout

```
linear_regression_model/
├── summative/
│   ├── linear_regression/    # Notebook, model outputs
│   ├── API/                  # FastAPI service (prediction.py, requirements.txt)
│   └── FlutterApp/           # Mobile client
```

More detail on the API and local `uvicorn` usage: [summative/API/README.md](summative/API/README.md).
