



# Express Reliability Platform V10

Welcome! This guide will help you get started with robotics, quantum computing, AIOps, and SRE—even if you’re a complete beginner.

---

## Chapters Covered
- Chapter 40: Robotics Layer
- Chapter 41: Quantum Computing Layer
- Chapter 42: AIOps and Automation
- Chapter 43: SRE Best Practices
- Chapter 44: Onboarding and Demo Instructions

---

## What You’ll Learn
1. How to run robotics and quantum computing demos
2. How to use AIOps for prediction and automated fixes
3. How to follow SRE best practices for reliability
4. How to onboard and demo the platform step-by-step

---


## Step-by-Step Guide: Getting Started

### 1. Install Prerequisites
You’ll need:
- Git (for downloading the project)
- Python (for running scripts)
- Node.js (for some automation)

Download and install these from their official websites.

### 2. Clone the Repository
Open your terminal and run:
```sh
git clone <URL-of-this-repo>
cd express-reliability-platform-course/express-reliability-platform-v10
```

### 3. Provision Infrastructure (Cloud or Local)
- **Cloud (Recommended for full testing):**
	- Use Terraform or AWS Console to create an EKS cluster (see previous versions for details)
	- Deploy platform components (robotics, quantum, aiops, etc.) as Kubernetes workloads
	- Use Helm charts for easy deployment and management
	- Run demos and DR drills in the EKS environment
- **Local (Quick start):**
	- Run all scripts and demos directly on your laptop
	- No cloud resources required for simulation and basic testing

### 4. Read the Docs
- Start with `docs/onboarding.md` for a simple onboarding guide
- Check `docs/demo_instructions.md` for how to run demos
- Review `docs/sre.md` for reliability tips, DR drills, and EKS guidance


### 4. Run the Robotics Demo and Remediation
```sh
python robotics/demo_robotics.py
```
You’ll see robots performing tasks—no hardware required!

#### Remediate Hospital Robot Issues
If you receive a Slack alert about a robot issue, run:
```sh
python robotics/remediate_robot.py
```
Follow the prompts to resolve errors, low battery, overheating, or network problems.

### 6. Run the Quantum Computing Demo
```sh
python quantum/demo_quantum.py
```
You’ll see quantum bits being processed—no quantum computer needed!


### 7. Advanced Slack Integration for Hospital Telemetry
Run the Slack integration script to emulate real hospital robot telemetry and incident alerts:
```sh
python slack/send_slack_message.py
```
This script generates realistic alerts and actionable recommendations for hospital operations.

### 8. Try AIOps and Automation
Use the AIOps scripts to predict problems and see how the platform can fix them automatically.

### 8. Practice SRE, DR Drills, and Incident Management
- Read the runbooks and SRE docs
- Try the drills and see how to respond to incidents
- Practice DR scenarios in both local and EKS environments

---

## How to Test Everything Locally
You don’t need cloud resources to try this out. Just run the demo scripts and AIOps locally on your laptop. All instructions are in the docs folder.

---

## Troubleshooting Tips
- If a script doesn’t work, make sure Python and Node.js are installed.
- Check you’re in the right folder before running a script.
- If you get an error, read the docs or search online for help.

---

## Example Directory Structure
- `robotics/`: Robotics demo scripts
- `quantum/`: Quantum computing demo scripts
- `aiops/`: Prediction, remediation, and SLO/SLI scripts
- `slack/`: Slack integration scripts
- `dr/`: Runbooks and disaster recovery guides
- `docs/`: Onboarding, demo instructions, and SRE documentation

---

## Next Steps
- Try making your own robotics or quantum demos
- Expand AIOps to cover more problems
- Write new runbooks and share with your team

---


