# Smart Road Condition Monitor

### Vibration-Based Pothole Detection using Smartphone Sensors and Machine Learning

A full-stack prototype that uses smartphone accelerometer data to assess road quality and identify pothole-like vibration patterns. The system combines a Flutter mobile application, a Flask inference API, and a Random Forest classifier trained on synthetic vibration data.

> **Project status:** College prototype / proof of concept. The current ML model is trained on synthetic accelerometer signals, so the reported classifications should not be interpreted as field-validated pothole detection.

---

## Overview

Poor road conditions can create safety risks and increase vehicle maintenance costs. This project explores whether vibration patterns captured by a smartphone can be used as a lightweight signal for road-condition monitoring.

During a recording session, the mobile application collects accelerometer readings at approximately **50 Hz** and GPS-based distance information. The recorded sensor data is sent to a Flask backend, where the z-axis signal is divided into fixed-size windows and converted into statistical features. A Random Forest model then classifies each window as:

* **Smooth**
* **Rough**
* **Pothole**

The backend aggregates the window-level predictions into an overall road-quality result and counts the predicted pothole windows.

---

## System Architecture

```text
┌──────────────────────────┐
│       Flutter App        │
│                          │
│  Accelerometer ~50 Hz    │
│  GPS distance tracking   │
│  Recording interface     │
└────────────┬─────────────┘
             │
             │ HTTP POST /analyze
             │ samples + distance + duration
             ▼
┌──────────────────────────┐
│      Flask Backend       │
│                          │
│  Input validation        │
│  Z-axis extraction       │
│  100-sample windows      │
│  Feature extraction      │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│  Random Forest Classifier│
│                          │
│ Smooth / Rough / Pothole │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│    Result Aggregation    │
│                          │
│ Majority road quality    │
│ Pothole-window count     │
└────────────┬─────────────┘
             │
             ├──────────────► results.csv
             │
             ▼
┌──────────────────────────┐
│   Flutter Result Screen  │
│                          │
│ Road quality             │
│ Potholes detected        │
│ Distance / duration      │
└──────────────────────────┘
```

---

## Key Technical Components

### 1. Sensor Data Collection

The Flutter application uses smartphone sensors to collect:

* X-axis acceleration
* Y-axis acceleration
* Z-axis acceleration
* Approximately 50 Hz accelerometer samples
* GPS-based distance information

The recording service maintains the sensor samples, distance travelled, and recording duration.

### 2. Signal Windowing

The backend extracts the z-axis acceleration signal and processes it using non-overlapping windows of **100 samples**.

At approximately 50 Hz, each window represents roughly **2 seconds of sensor data**.

### 3. Feature Extraction

Four statistical features are extracted from each window:

| Feature          | Purpose                         |
| ---------------- | ------------------------------- |
| Mean             | Average acceleration level      |
| Absolute Maximum | Captures large vibration spikes |
| Variance         | Measures signal variability     |
| RMS              | Represents signal magnitude     |

These features are implemented directly in the backend feature-extraction pipeline.

### 4. Machine Learning

The training pipeline currently generates a synthetic vibration dataset containing three classes:

* Smooth road
* Rough road
* Pothole-like vibration

The training script generates **500 synthetic windows per class**, extracts four statistical features, performs a stratified 80/20 train-test split, and trains a `RandomForestClassifier` with 100 trees.
The trained model is serialized using Joblib and loaded by the Flask backend during startup.

### 5. Backend Inference

The Flutter application sends the recorded samples, distance, and duration to:

```text
POST /analyze
```

The backend:

1. Validates the request
2. Extracts the z-axis signal
3. Creates 100-sample windows
4. Extracts statistical features
5. Runs Random Forest inference
6. Counts windows classified as potholes
7. Determines the majority road-quality class
8. Stores the result in CSV
9. Returns the result to the mobile application

### 6. Mobile Result Interface

The Flutter result screen displays:

* Overall road quality
* Pothole-window count
* Distance travelled
* Recording duration

---

## Repository Structure

```text
smart-road-condition-monitor/
│
├── README.md
│
├── flutter_app/
│   ├── pubspec.yaml
│   └── lib/
│       ├── main.dart
│       ├── models/
│       │   └── sensor_sample.dart
│       ├── services/
│       │   ├── api_service.dart
│       │   └── recording_service.dart
│       └── screens/
│           ├── home_screen.dart
│           └── result_screen.dart
│
├── backend/
│   ├── app.py
│   ├── requirements.txt
│   └── road_model.pkl
│
├── ml/
│   └── train_model.py
│
└── data/
    └── results.csv
```

---

## Running the Project

### Prerequisites

* Python 3.x
* Flutter SDK
* Android Studio / Android SDK
* Android emulator or physical Android device
* Git

### 1. Train the ML Model

```bash
cd ml

pip install numpy pandas scikit-learn joblib

python train_model.py
```

This generates:

```text
backend/road_model.pkl
```

### 2. Start the Flask Backend

```bash
cd backend

pip install -r requirements.txt

python app.py
```

The server runs on port `5000`.

Test the backend:

```bash
curl http://localhost:5000/health
```

Expected response:

```json
{
  "status": "ok"
}
```

### 3. Configure the Flutter API

Open:

```text
flutter_app/lib/services/api_service.dart
```

Configure the backend URL depending on your environment:

| Environment                    | Backend URL                  |
| ------------------------------ | ---------------------------- |
| Android Emulator               | `http://10.0.2.2:5000`       |
| Physical Android on same Wi-Fi | `http://YOUR-PC-LAN-IP:5000` |
| iOS Simulator                  | `http://localhost:5000`      |

The current implementation uses `10.0.2.2` for Android emulator communication.

### 4. Run the Flutter Application

```bash
cd flutter_app

flutter pub get

flutter run
```

Start a recording, collect at least 100 samples, stop the recording, and the application sends the session to the backend for analysis.

---

## API Reference

### `POST /analyze`

Example request:

```json
{
  "samples": [
    {
      "ax": 0.1,
      "ay": 0.2,
      "az": 9.8
    }
  ],
  "distance": 1200,
  "duration": 300
}
```

Example response:

```json
{
  "road_quality": "Rough",
  "potholes": 3
}
```

### `GET /health`

```json
{
  "status": "ok"
}
```

---

## ML Pipeline

The current baseline follows:

```text
Accelerometer Signal
        ↓
Z-axis Extraction
        ↓
100-Sample Window
        ↓
Mean + |Max| + Variance + RMS
        ↓
Random Forest
        ↓
Smooth / Rough / Pothole
```

The synthetic data generator models smooth roads using low-variance signals, rough roads using higher-variance signals, and potholes using baseline noise with large acceleration spikes.

---

## Limitations

This project is currently a **proof of concept**, with several limitations:

1. The current classifier is trained on synthetic rather than field-collected road data.
2. Only the accelerometer z-axis is currently used for inference.
3. The feature set contains four simple statistical features.
4. The system uses fixed, non-overlapping windows.
5. Phone orientation, mounting position, vehicle type, speed, suspension, and sensor noise can affect the signal.
6. A reported pothole count represents the number of windows classified as pothole-like; it does not guarantee the number of physically distinct potholes.

These limitations define the next stage of the project rather than being hidden from the evaluation.

---

## Future Research Directions

Potential extensions include:

* Collecting and labeling real-world accelerometer datasets
* Evaluating multiple smartphone orientations and mounting positions
* Fusing X, Y, and Z accelerometer signals
* Applying digital filtering and frequency-domain analysis
* Investigating FFT-based vibration features
* Comparing Random Forest with SVM, XGBoost, CNN, and sequence models
* Testing overlapping windows for finer event detection
* Incorporating vehicle speed and GPS context
* Evaluating robustness across different smartphones and vehicles
* Building a larger geospatial road-quality dataset
* Comparing the approach with existing road-condition detection methods

---

## Project Motivation

The project explores a lightweight approach to intelligent transportation monitoring by combining:

**Mobile Sensing + Signal Analysis + Machine Learning + Geospatial Context**

The current implementation provides a reproducible baseline that can be extended toward real-world sensor-data collection, more advanced signal-processing techniques, and stronger machine-learning models.

---

## Author

**Yellu Krishna Chaitanya Reddy**

B.Tech — CSE (AI & ML)
CVR College of Engineering

* GitHub: `https://github.com/KrishnaChaitanya-aiml`
* LinkedIn: `https://www.linkedin.com/in/yellu-krishna-chaitanya-reddy-9a0061349/`

---

## License

Developed as a college prototype for learning, experimentation, and further research.
