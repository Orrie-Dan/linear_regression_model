import joblib
import numpy as np
import os


THIS_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(THIS_DIR, "outputs", "best_aqi_model.pkl")


def load_artifact():
    """Load the saved best model artifact (model, scaler, features)."""
    return joblib.load(MODEL_PATH)


def predict_one_scaled(features_scaled: np.ndarray) -> float:
    """
    Predict AQI for a single, already-scaled feature row using the best model.

    Parameters
    ----------
    features_scaled : np.ndarray
        Feature vector scaled with the same StandardScaler used during training.
        Shape should be (n_features,) or (1, n_features).

    Returns
    -------
    float
        Predicted AQI value.
    """
    artifact = load_artifact()
    model = artifact["model"]
    X = np.atleast_2d(features_scaled)
    return float(model.predict(X)[0])


if __name__ == "__main__":
    print(
        "This script loads the best saved model from "
        f\"{MODEL_PATH}\" \" and exposes predict_one_scaled(features_scaled).\\n\"
        \"Use it in Task 2 to call the trained model from your API or app.\"
    )

