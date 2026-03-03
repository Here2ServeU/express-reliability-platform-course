# Remediation Script for Hospital Robot
import random

robot_id = input("Enter robot ID to remediate: ")
issue = input("Describe the issue (e.g., error, low battery, overheating, network): ")

print(f"Remediation started for Robot #{robot_id}")

if "error" in issue.lower():
    print("- Rebooting robot...")
    print("- Running diagnostics...")
    print("- Error resolved. Robot is operational.")
elif "battery" in issue.lower():
    print("- Sending robot to charging station...")
    print("- Battery charging. Please wait...")
    print("- Battery level restored.")
elif "overheat" in issue.lower() or "temperature" in issue.lower():
    print("- Pausing robot tasks...")
    print("- Cooling down robot...")
    print("- Temperature normalized. Resuming tasks.")
elif "network" in issue.lower():
    print("- Checking network connection...")
    print("- Reconnecting to hospital WiFi...")
    print("- Network restored.")
else:
    print("- Issue not recognized. Please consult runbook or escalate to SRE team.")

print(f"Remediation complete for Robot #{robot_id}")