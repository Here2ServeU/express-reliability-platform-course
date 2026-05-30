import time


def main() -> None:
    print("Hospital robotics simulation starting...")
    robots = [
        ("RX-01", "medication delivery"),
        ("RX-02", "lab sample transport"),
        ("RX-03", "room sanitation"),
    ]

    for robot_id, task in robots:
        print(f"{robot_id} assigned to {task}.")
        time.sleep(1)
        print(f"{robot_id} completed {task} successfully.")

    print("Hospital robotics simulation complete.")


if __name__ == "__main__":
    main()