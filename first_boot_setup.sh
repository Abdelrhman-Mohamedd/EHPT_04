#!/usr/bin/env bash
# ==============================================================================
# first_boot_setup.sh — Student First-Boot Personalization Wizard (GUI Mode)
# Triggered via GNOME autostart .desktop file (NOT .bash_profile).
# Uses zenity GUI dialogs — no raw terminal input required.
# Removes its own autostart entry on success so it never runs again.
# ==============================================================================

# setup.sh lives in /opt/lab04-setup/ (root:root 700 — student cannot read or list it)
# The secret salt is stored in /etc/lab04.conf (root:root 600 — student cannot read it)
# This script only receives the Student ID from the user and passes it to sudo setup.sh
SETUP_SCRIPT="/opt/lab04-setup/setup.sh"
FIRST_BOOT_FLAG="/home/student/.lab04_provisioned"
AUTOSTART_DESKTOP="/home/student/.config/autostart/lab04-setup.desktop"

# ---- Guard: only run once ----
if [ -f "$FIRST_BOOT_FLAG" ]; then
    exit 0
fi

# ---- Dependency check ----
if ! command -v zenity >/dev/null 2>&1; then
    notify-send "Lab 04 Setup" "Error: zenity is not installed. Please contact your instructor." 2>/dev/null || true
    exit 1
fi

# ---- Welcome Dialog ----
zenity --info \
    --title="VaultTech Ethical Hacking Lab 04" \
    --width=460 \
    --text="<b>Welcome to Lab 04: Advanced Buffer Overflow</b>\n\nThis VM must be personalized using your unique <b>Student ID</b> before you can begin.\n\nThis lab covers the OSCP Methodology:\n• Fuzzing & Offset Discovery\n• Bad Character Analysis\n• JMP RSP Gadget Hunting\n• Shellcode Generation\n\nClick <b>OK</b> to continue." \
    2>/dev/null || exit 1

# ---- Student ID Input + Confirmation Loop ----
while true; do
    SID=$(zenity --entry \
        --title="Lab 04 — Student ID Required" \
        --width=420 \
        --text="Enter your <b>Student ID</b> exactly as assigned by your instructor.\n\n<small>Example: 231000000</small>" \
        --entry-text="" \
        2>/dev/null)

    # X / Cancel button pressed — abort entirely
    if [ $? -ne 0 ]; then
        zenity --warning --title="Lab 04 Setup" --width=380 \
            --text="Setup cancelled. Please log out and log back in to try again." \
            2>/dev/null || true
        exit 1
    fi

    SID="${SID// /_}"  # Replace spaces with underscores

    if [[ -z "$SID" ]]; then
        zenity --error --title="Invalid Input" --width=380 \
            --text="Student ID cannot be empty. Please try again." 2>/dev/null || true
        continue
    fi

    if [[ ! "$SID" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        zenity --error --title="Invalid Input" --width=380 \
            --text="Invalid characters in Student ID.\n\nOnly letters, digits, hyphens ( - ) and underscores ( _ ) are allowed." 2>/dev/null || true
        continue
    fi

    # ---- Confirmation Dialog ----
    zenity --question \
        --title="Confirm Student ID" \
        --width=420 \
        --text="Your Student ID is:\n\n<b>${SID}</b>\n\nAre you sure this is correct?\n<small>This cannot be changed after confirming.</small>" \
        2>/dev/null

    if [ $? -eq 0 ]; then
        break   # "Yes" — proceed to provisioning
    fi
    # "No" — loop back and ask for the ID again
done

# ---- Progress: Run setup.sh in background, show progress bar ----
(
    echo "# Provisioning lab environment for ${SID}..."
    echo "10"

    sudo "$SETUP_SCRIPT" "$SID" --production > /tmp/lab04_setup.log 2>&1
    SETUP_EXIT=$?

    echo "90"
    sleep 1
    echo "100"

    echo "$SETUP_EXIT" > /tmp/lab04_setup_exit
) | zenity --progress \
    --title="Lab 04 Setup — Please Wait" \
    --width=460 \
    --text="Personalizing your lab environment...\n\nThis will take approximately 30 seconds." \
    --percentage=0 \
    --auto-close \
    --no-cancel \
    2>/dev/null

# ---- Read exit code ----
SETUP_EXIT=1
if [ -f /tmp/lab04_setup_exit ]; then
    SETUP_EXIT=$(cat /tmp/lab04_setup_exit)
    rm -f /tmp/lab04_setup_exit
fi

if [ "$SETUP_EXIT" -eq 0 ]; then
    VM_IP=$(hostname -I | awk '{print $1}')

    # Mark as provisioned
    touch "$FIRST_BOOT_FLAG"

    # Remove the GNOME autostart entry
    rm -f "$AUTOSTART_DESKTOP" 2>/dev/null || true

    # Self-delete this wizard script
    rm -f /home/student/first_boot_setup.sh 2>/dev/null || true

    # ---- Success Dialog ----
    zenity --info \
        --title="Lab 04 Ready! 🎉" \
        --width=480 \
        --text="<b>Your lab environment is ready!</b>\n\n<b>Student ID:</b> ${SID}\n\nThe vulnerable Vault server is now running in the background on port 9999.\n\nOpen a terminal and type <b>nc 127.0.0.1 9999</b> to connect and begin your exploitation methodology.\n\nGood luck!" \
        2>/dev/null || true
else
    SETUP_LOG=$(cat /tmp/lab04_setup.log 2>/dev/null | tail -20 || echo "No log output.")
    zenity --error \
        --title="Lab 04 Setup Failed" \
        --width=480 \
        --text="Lab provisioning failed.\n\nPlease contact your instructor and provide the following log:\n\n<tt>${SETUP_LOG}</tt>" \
        2>/dev/null || true
fi
