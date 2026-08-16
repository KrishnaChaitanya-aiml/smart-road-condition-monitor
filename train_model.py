"""
train_model.py
--------------
Generates a synthetic vibration dataset and trains a RandomForest classifier.
Three road classes:
  0 = smooth   (low variance z-axis)
  1 = rough    (medium variance z-axis)
  2 = pothole  (high spike in z-axis)

Features per 100-sample window:
  mean, max, variance, rms
"""

import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report
import joblib
import os

# ── reproducibility ──────────────────────────────────────────────
np.random.seed(42)

SAMPLES_PER_WINDOW = 100
WINDOWS_PER_CLASS  = 500          # synthetic windows per class

# ── helpers ──────────────────────────────────────────────────────

def rms(arr):
    return np.sqrt(np.mean(arr ** 2))

def extract_features(window: np.ndarray) -> dict:
    """Extract 4 features from a 1-D z-axis window."""
    return {
        "mean":     np.mean(window),
        "max":      np.max(np.abs(window)),   # absolute max catches negative spikes
        "variance": np.var(window),
        "rms":      rms(window),
    }

# ── synthetic data generation ─────────────────────────────────────

def generate_smooth(n=WINDOWS_PER_CLASS):
    """Smooth road: z ≈ 9.8 m/s² ± small noise."""
    rows = []
    for _ in range(n):
        z = np.random.normal(loc=9.8, scale=0.05, size=SAMPLES_PER_WINDOW)
        rows.append({**extract_features(z), "label": 0})
    return rows

def generate_rough(n=WINDOWS_PER_CLASS):
    """Rough road: z ≈ 9.8 m/s² ± medium noise."""
    rows = []
    for _ in range(n):
        z = np.random.normal(loc=9.8, scale=0.4, size=SAMPLES_PER_WINDOW)
        rows.append({**extract_features(z), "label": 1})
    return rows

def generate_pothole(n=WINDOWS_PER_CLASS):
    """Pothole: base noise + 1-3 large spikes."""
    rows = []
    for _ in range(n):
        z = np.random.normal(loc=9.8, scale=0.2, size=SAMPLES_PER_WINDOW)
        # inject 1–3 random spikes (pothole impacts)
        num_spikes = np.random.randint(1, 4)
        spike_idx  = np.random.choice(SAMPLES_PER_WINDOW, num_spikes, replace=False)
        z[spike_idx] += np.random.uniform(3.0, 7.0, size=num_spikes)
        rows.append({**extract_features(z), "label": 2})
    return rows

# ── assemble dataset ──────────────────────────────────────────────

print("Generating synthetic dataset …")
data = generate_smooth() + generate_rough() + generate_pothole()
df   = pd.DataFrame(data)

feature_cols = ["mean", "max", "variance", "rms"]
X = df[feature_cols].values
y = df["label"].values

print(f"  Total samples : {len(df)}")
print(f"  Class counts  : {dict(zip(*np.unique(y, return_counts=True)))}")

# ── train / test split ────────────────────────────────────────────

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

# ── train model ───────────────────────────────────────────────────

print("\nTraining RandomForestClassifier …")
model = RandomForestClassifier(n_estimators=100, random_state=42, n_jobs=-1)
model.fit(X_train, y_train)

# ── evaluate ──────────────────────────────────────────────────────

y_pred = model.predict(X_test)
print("\nClassification Report:")
print(classification_report(y_pred, y_test, target_names=["smooth", "rough", "pothole"]))

# ── save model ────────────────────────────────────────────────────

os.makedirs("../backend", exist_ok=True)
model_path = "../backend/road_model.pkl"
joblib.dump(model, model_path)
print(f"Model saved → {model_path}")
