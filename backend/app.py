"""
app.py – Smart Road Monitor – Flask Backend (Production Ready)
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import numpy as np
import joblib
import csv
import os
from datetime import datetime
from collections import Counter

# ── config ────────────────────────────────────────────────────────

BASE_DIR    = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH  = os.path.join(BASE_DIR, "road_model.pkl")
CSV_PATH    = os.path.join(BASE_DIR, "results.csv")   # FIXED (Render-safe)
WINDOW_SIZE = 100
LABEL_MAP   = {0: "Smooth", 1: "Rough", 2: "Pothole"}

# ── app & model ───────────────────────────────────────────────────

app = Flask(__name__)
CORS(app)  # 🔥 IMPORTANT for Flutter communication

# Load model once at startup
if not os.path.exists(MODEL_PATH):
    raise FileNotFoundError(
        f"Model not found at {MODEL_PATH}. Make sure road_model.pkl is uploaded."
    )

model = joblib.load(MODEL_PATH)
print(f"[✓] Model loaded from {MODEL_PATH}")

# ── CSV storage ───────────────────────────────────────────────────

def save_to_csv(distance, duration, potholes, road_quality):
    """Append one result row to CSV (temporary storage)."""
    file_exists = os.path.isfile(CSV_PATH)

    with open(CSV_PATH, "a", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["timestamp", "distance", "duration", "potholes", "road_quality"]
        )
        if not file_exists:
            writer.writeheader()

        writer.writerow({
            "timestamp": datetime.utcnow().isoformat(),
            "distance": distance,
            "duration": duration,
            "potholes": potholes,
            "road_quality": road_quality
        })

# ── feature extraction ────────────────────────────────────────────

def extract_features(window: np.ndarray):
    """Extract statistical features from Z-axis window."""
    mean     = float(np.mean(window))
    abs_max  = float(np.max(np.abs(window)))
    variance = float(np.var(window))
    rms      = float(np.sqrt(np.mean(window ** 2)))
    return [mean, abs_max, variance, rms]

# ── main analysis route ───────────────────────────────────────────

@app.route("/analyze", methods=["POST"])
def analyze():
    try:
        body = request.get_json(force=True)

        # ── validation ────────────────────────────────────────────
        if not body or "samples" not in body:
            return jsonify({"error": "Missing 'samples' in request"}), 400

        samples  = body["samples"]
        distance = float(body.get("distance", 0))
        duration = float(body.get("duration", 0))

        if len(samples) < WINDOW_SIZE:
            return jsonify({
                "error": f"Need at least {WINDOW_SIZE} samples, got {len(samples)}"
            }), 400

        # ── extract z-axis ────────────────────────────────────────
        z_values = np.array([s["az"] for s in samples], dtype=float)

        # ── windowing ─────────────────────────────────────────────
        feature_rows = []

        for i in range(0, len(z_values) - WINDOW_SIZE + 1, WINDOW_SIZE):
            window = z_values[i:i + WINDOW_SIZE]
            feature_rows.append(extract_features(window))

        if not feature_rows:
            return jsonify({"error": "Not enough data for processing"}), 400

        # ── ML prediction ─────────────────────────────────────────
        predictions = model.predict(feature_rows)

        # ── pothole count ─────────────────────────────────────────
        potholes = int(np.sum(predictions == 2))

        # ── majority vote ─────────────────────────────────────────
        majority_label = Counter(predictions).most_common(1)[0][0]
        road_quality   = LABEL_MAP[int(majority_label)]

        # ── save result ───────────────────────────────────────────
        save_to_csv(distance, duration, potholes, road_quality)

        print(f"[✓] {road_quality} | potholes={potholes}")

        return jsonify({
            "road_quality": road_quality,
            "potholes": potholes
        })

    except Exception as e:
        print(f"[ERROR] {str(e)}")
        return jsonify({"error": str(e)}), 500

# ── health check ──────────────────────────────────────────────────

@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})

# ── entry point ───────────────────────────────────────────────────

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
