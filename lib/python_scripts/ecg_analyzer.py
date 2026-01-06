#!/usr/bin/env python3
"""Simple ECG analyzer invoked by the Rails backend."""

import json
import math
import sys
from typing import Any, Dict, List

WINDOW_SIZE = 5


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError as exc:  # pragma: no cover - safety net
        _emit_error(f"Invalid JSON payload: {exc}")
        return

    data_points = payload.get("data_points", [])
    sampling_rate = payload.get("sampling_rate", 0)

    filtered = _moving_average(data_points, WINDOW_SIZE)
    anomalies = _detect_anomalies(filtered, sampling_rate)

    result: Dict[str, Any] = {
        "filtered_data": {
            "sampling_rate": sampling_rate,
            "data_points": filtered,
        },
        "anomalies": anomalies,
    }

    json.dump(result, sys.stdout)


def _moving_average(data: List[float], window: int) -> List[float]:
    if not data or window <= 1 or len(data) <= window:
        return data

    averages = [
        sum(data[idx : idx + window]) / window
        for idx in range(0, len(data) - window + 1)
    ]

    head_padding = [averages[0]] * (window - 1)
    return head_padding + averages


def _detect_anomalies(data: List[float], sampling_rate: float) -> List[Dict[str, float]]:
    if not data or sampling_rate <= 0:
        return []

    threshold = max(data) * 0.6
    peaks = [
        idx
        for idx in range(1, len(data) - 1)
        if data[idx] > threshold and data[idx] > data[idx - 1] and data[idx] > data[idx + 1]
    ]

    if len(peaks) < 2:
        return []

    rr_intervals = [
        (peaks[idx + 1] - peaks[idx]) / sampling_rate
        for idx in range(len(peaks) - 1)
    ]

    if not rr_intervals:
        return []

    mean_rr = sum(rr_intervals) / len(rr_intervals)
    variance = sum((interval - mean_rr) ** 2 for interval in rr_intervals) / len(rr_intervals)
    std_rr = math.sqrt(variance)

    if std_rr == 0:
        return []

    anomalies = []
    for idx, interval in enumerate(rr_intervals):
        deviation = abs(interval - mean_rr)
        if deviation <= 2 * std_rr:
            continue

        start_idx = peaks[idx]
        end_idx = peaks[idx + 1] if idx + 1 < len(peaks) else len(data) - 1
        score = min(deviation / (3 * std_rr), 1.0)
        anomalies.append(
            {
                "start_time": start_idx / sampling_rate,
                "end_time": end_idx / sampling_rate,
                "score": score,
            }
        )

    return anomalies


def _emit_error(message: str) -> None:
    json.dump({"error": message}, sys.stdout)


if __name__ == "__main__":
    main()
