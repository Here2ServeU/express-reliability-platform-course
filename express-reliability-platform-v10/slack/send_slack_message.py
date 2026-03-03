

# Advanced Hospital Telemetry & Slack Integration
import random
import datetime

robot_id = random.randint(100, 999)
telemetry = {
	"battery": random.randint(5, 100),
	"location": random.choice(["ICU", "ER", "Lab", "Ward", "Pharmacy", "Radiology"]),
	"status": random.choice(["Idle", "Active", "Charging", "Error", "Maintenance"]),
	"temperature": round(random.uniform(20.0, 40.0), 1),
	"last_maintenance": (datetime.datetime.now() - datetime.timedelta(days=random.randint(0, 60))).strftime('%Y-%m-%d'),
	"network": random.choice(["Online", "Offline", "Intermittent"]),
	"payload": random.choice(["Medicine", "Lab Sample", "Documents", "None"])
}

incident = input("Describe the hospital incident (e.g., robot stuck, telemetry error, patient alert): ")

print(f"Slack Alert: Hospital Robot #{robot_id}")
print(f"Location: {telemetry['location']}")
print(f"Status: {telemetry['status']}")
print(f"Battery: {telemetry['battery']}% | Temperature: {telemetry['temperature']}°C")
print(f"Network: {telemetry['network']} | Payload: {telemetry['payload']}")
print(f"Last Maintenance: {telemetry['last_maintenance']}")
print(f"Incident: {incident}")

# Advanced recommendations
actions = []
if telemetry['status'] == "Error":
	actions.append("Dispatch engineer to check robot error.")
if telemetry['battery'] < 15:
	actions.append("Send robot to charging station immediately.")
if telemetry['temperature'] > 37.0:
	actions.append("Check for overheating and pause robot tasks.")
if telemetry['network'] != "Online":
	actions.append("Investigate network connectivity issues.")
if (datetime.datetime.now() - datetime.datetime.strptime(telemetry['last_maintenance'], '%Y-%m-%d')).days > 30:
	actions.append("Schedule maintenance for robot.")
if telemetry['payload'] != "None" and telemetry['status'] == "Idle":
	actions.append(f"Alert staff: Robot is idle with {telemetry['payload']} onboard.")

if actions:
	print("Recommended Actions:")
	for act in actions:
		print(f"- {act}")
else:
	print("Status: Monitoring. No immediate action required.")