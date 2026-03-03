# Express Reliability Platform V1 — Local Foundation

## Chapters Covered
- Chapter 1: What You Are Building and Why It Matters
- Chapter 2: Running the App on Your Computer
- Chapter 3: From Shared Platform to Your Working Version

## Overview
Version 1 is your starting point. You will learn what a web application is, why structure matters, and how to run the app locally with confidence. This version reflects the practical steps I took to rapidly transition into senior-level IT roles from a full-time pastoral ministry background.

## Architecture
- **Express app**: Receives requests, sends responses
- **Local only**: Runs on your computer, not the cloud

## Prerequisites
- Node.js
- Git
- Visual Studio Code

## Run Locally
After you have pushed your project to your own GitHub repository, you can run it locally:

1. Install Node.js, Git, and VS Code (see chapter instructions)
2. Clone your repository from GitHub:
   ```sh
   git clone https://github.com/YOUR_USERNAME/express-reliability-platform-v1.git
   cd express-reliability-platform-v1
   ```
3. Install dependencies:
   ```sh
   npm install
   ```
4. Start the app:
   ```sh
   npm start
   ```
5. Open your browser at [http://localhost:3000](http://localhost:3000)

## Project Structure
- `package.json`: App info + dependencies
- `index.js`: Server entry point
- `public/index.html`: Webpage users see
- `node_modules/`: Installed packages
- `.gitignore`: Files Git should ignore
- `README.md`: Project instructions

## What I Learned
- What local development means
- How to install tools and run an app
- How to read logs and solve beginner problems
- Why structure and discipline matter

---

## How to Make This Your Own Project and Push to GitHub

### 1. Create a GitHub Account
- Go to [https://github.com](https://github.com)
- Click **Sign Up** and follow the instructions to create your account
- Verify your email address

### 2. Configure Git on Your Local Machine
- Open your terminal
- Set your name and email (replace with your info):
  ```sh
  git config --global user.name "Your Name"
  git config --global user.email "your.email@example.com"
  ```
- (Optional) Generate an SSH key for secure access:
  ```sh
  ssh-keygen -t ed25519 -C "your.email@example.com"
  # Follow prompts, then add the public key to GitHub (Settings > SSH and GPG keys)
  ```

### 3. Clone the Starter Project to Your Local Machine
- In your workspace directory, run:
  ```sh
  git clone https://github.com/Here2ServeU/express-reliability-platform-course.git
  cd express-reliability-platform-course/express-reliability-platform-v1
  ```

### 4. Create a New Repository on Your GitHub Account
- Log in to GitHub
- Click the **+** icon (top right) > **New repository**
- Name it `express-reliability-platform-v1`
- Add a description (optional)
- Choose **Public** or **Private**
- Click **Create repository**

### 5. Initialize Git Locally and Push to Your GitHub
- In your project folder:
  ```sh
  git init
  git add .
  git commit -m "Initial commit: my version 1"
  git branch -M main
  git remote add origin https://github.com/YOUR_USERNAME/express-reliability-platform-v1.git
  git push -u origin main
  ```
- Replace `YOUR_USERNAME` with your GitHub username

### 6. Troubleshooting Common Issues
- **Error: Permission denied (publickey)**
  - Make sure your SSH key is added to GitHub
  - Or use HTTPS instead of SSH for remote URL
- **Error: Repository not found**
  - Double-check the remote URL and your username
- **Error: Nothing to commit**
  - Run `git status` to see if files are staged
  - Use `git add .` to stage all files
- **Error: Remote rejected**
  - Make sure you have permission to push
  - Check if you need to authenticate (login)
- **General tip:**
  - Read the first error line, not the last
  - Search for the error message online or ask for help

---

By following these steps, you can create own version of the project, push it to GitHub, and begin building your portfolio. Troubleshooting tips help you solve common problems calmly and confidently.
