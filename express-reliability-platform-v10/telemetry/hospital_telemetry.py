import random
from datetime import datetime


def main() -> None:
    telemetry = {
        "timestamp": datetime.utcnow().isoformat(timespec="seconds") + "Z",
        "robot_id": "RX-02",
        "battery_percent": random.randint(35, 100),
        "avg_response_ms": random.randint(90, 450),
        "error_rate_percent": round(random.uniform(0.0, 3.5), 2),
        "active_alert": random.choice(["none", "latency", "sensor_fault"]),
    }

    print("Hospital telemetry snapshot")
    for key, value in telemetry.items():
        print(f"- {key}: {value}")


if __name__ == "__main__":
    main()