#!/bin/sh

# Function to check if a command exists
command_exists() {
    command -v "$1" > /dev/null 2>&1
}

# Install on Debian/Ubuntu-based systems
install_on_debian() {
    echo "Installing $1..."
    sudo apt update
    sudo apt install -y "$1"
}

# Install on Red Hat/CentOS/Fedora-based systems
install_on_redhat() {
    echo "Installing $1..."
    sudo yum install -y "$1"
}

# Install on Arch-based systems
install_on_arch() {
    echo "Installing $1..."
    sudo pacman -Sy --noconfirm "$1"
}

# Install on BSD-based systems
install_on_bsd() {
    echo "Installing $1..."
    env ASSUME_ALWAYS_YES=yes sudo pkg install -y "$1"
}

# Install on macOS
install_on_macos() {
    echo "Installing $1..."
    if command_exists brew; then
        brew install "$1"
    else
        echo "Homebrew is not installed. Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        brew install "$1"
    fi
}

set -e

# Get the Python version
PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')

# Compare the Python version with 3.8
REQUIRED_VERSION="3.8"

if [ "$(echo -e "$PYTHON_VERSION\n$REQUIRED_VERSION" | sort -V | head -n1)" = "$REQUIRED_VERSION" ]; then
    echo "Python version $PYTHON_VERSION is >= $REQUIRED_VERSION. Continuing..."
else
    echo "ERROR: Python version $PYTHON_VERSION is < $REQUIRED_VERSION. Exiting..."
    exit 1
fi

if [ -d ".venv/" ]; then
    echo ".venv exists. Installing requirements.txt..."
    .venv/bin/pip install -r requirements.txt
else
    echo "Making .venv and installing requirements.txt..."

    if [ "$(uname)" = "Linux" ]; then
       # Detect the package manager for venv installation check.
       if command_exists apt; then
           echo "Detected Debian-based system. Checking python3-venv."
           if dpkg -l | grep -q "python3-venv"; then
               echo "python3-venv found."
           else
               echo "python3-venv not found, installing..."
               install_on_debian "python3-venv"
           fi
       fi
    fi

    python3 -m venv .venv
    .venv/bin/pip install -r requirements.txt

fi

if command_exists ffmpeg; then
    echo "ffmpeg exists."
else
    echo "ffmpeg does not exist."

    # Detect the platform and install ffmpeg accordingly.
    case "$(uname)" in
        Linux)
            if command_exists apt; then
                echo "Detected Debian-based system."
                install_on_debian "ffmpeg"
            elif command_exists yum; then
                echo "Detected Red Hat-based system."
                echo "Installing needed repos for ffmpeg..."
                sudo yum config-manager --set-enabled crb > /dev/null 2>&1 || true
                sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E %rhel).noarch.rpm https://dl.fedoraproject.org/pub/epel/epel-next-release-latest-$(rpm -E %rhel).noarch.rpm > /dev/null 2>&1 || true
                sudo yum install -y --nogpgcheck https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-$(rpm -E %rhel).noarch.rpm https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-$(rpm -E %rhel).noarch.rpm > /dev/null 2>&1 || true
                install_on_redhat "ffmpeg"
            elif command_exists pacman; then
                echo "Detected Arch-based system."
                install_on_arch "ffmpeg"
            else
                echo "Unsupported Linux distribution."
                exit 1
            fi
            ;;
        FreeBSD|NetBSD|OpenBSD)
            echo "Detected BSD-based system."
            install_on_bsd "ffmpeg"
            ;;
        Darwin)
            echo "Detected macOS."
            install_on_macos "ffmpeg"
            ;;
        *)
            echo "Unsupported operating system."
            exit 1
            ;;
    esac
fi

sed -i.bak '1s|.*|#!.venv/bin/python3|' test_run.py
sudo chmod +x test_run.py
echo 'Everything is installed!'
echo 'Run StreamingCommunity with "./test_run.py"'