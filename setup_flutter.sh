#!/bin/bash

# ==============================================================================
# Flutter SDK Setup Script for IoT Plant Monitoring System
# ==============================================================================
# This script downloads and sets up the Flutter SDK, then builds the frontend.
# Run this if you don't have Flutter installed.
#
# Usage: ./setup_flutter.sh [options]
#   --skip-sdk     Skip Flutter SDK download (if already installed elsewhere)
#   --web-only     Only set up for web development
#   --help         Show this help message
# ==============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
FLUTTER_VERSION="3.24.0"  # Stable version
FLUTTER_CHANNEL="stable"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUTTER_DIR="$SCRIPT_DIR/flutter_sdk"
FLUTTER_APP_DIR="$SCRIPT_DIR/flutter_app"

# Parse arguments
SKIP_SDK=false
WEB_ONLY=false

for arg in "$@"; do
    case $arg in
        --skip-sdk)
            SKIP_SDK=true
            shift
            ;;
        --web-only)
            WEB_ONLY=true
            shift
            ;;
        --help)
            echo "Usage: ./setup_flutter.sh [options]"
            echo "  --skip-sdk     Skip Flutter SDK download (use system Flutter)"
            echo "  --web-only     Only set up for web development"
            echo "  --help         Show this help message"
            exit 0
            ;;
    esac
done

# ==============================================================================
# Helper Functions
# ==============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)     OS="linux";;
        Darwin*)    OS="macos";;
        MINGW*|MSYS*|CYGWIN*)    OS="windows";;
        *)          OS="unknown";;
    esac
    echo $OS
}

# Detect architecture
detect_arch() {
    case "$(uname -m)" in
        x86_64)     ARCH="x64";;
        arm64|aarch64)  ARCH="arm64";;
        *)          ARCH="x64";;
    esac
    echo $ARCH
}

# ==============================================================================
# Main Setup
# ==============================================================================

print_header "IoT Plant Monitoring System - Flutter Setup"

OS=$(detect_os)
ARCH=$(detect_arch)

print_info "Detected OS: $OS ($ARCH)"

# Check for required tools
print_header "Checking Prerequisites"

# Check for git
if command -v git &> /dev/null; then
    print_success "Git is installed"
else
    print_error "Git is not installed. Please install git first."
    exit 1
fi

# Check for curl or wget
if command -v curl &> /dev/null; then
    DOWNLOAD_CMD="curl -L -o"
    print_success "curl is available"
elif command -v wget &> /dev/null; then
    DOWNLOAD_CMD="wget -O"
    print_success "wget is available"
else
    print_error "Neither curl nor wget found. Please install one of them."
    exit 1
fi

# Check for unzip (Linux)
if [ "$OS" = "linux" ] || [ "$OS" = "macos" ]; then
    if command -v unzip &> /dev/null; then
        print_success "unzip is available"
    else
        print_warning "unzip not found. Attempting to install..."
        if [ "$OS" = "linux" ]; then
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y unzip
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y unzip
            elif command -v pacman &> /dev/null; then
                sudo pacman -S --noconfirm unzip
            fi
        fi
    fi
fi

# ==============================================================================
# Flutter SDK Download
# ==============================================================================

if [ "$SKIP_SDK" = false ]; then
    print_header "Setting up Flutter SDK"

    # Check if Flutter is already installed in the project
    if [ -d "$FLUTTER_DIR" ] && [ -f "$FLUTTER_DIR/bin/flutter" ]; then
        print_warning "Flutter SDK already exists at $FLUTTER_DIR"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Using existing Flutter SDK"
            FLUTTER_BIN="$FLUTTER_DIR/bin/flutter"
        else
            rm -rf "$FLUTTER_DIR"
        fi
    fi

    # Download Flutter if needed
    if [ ! -f "$FLUTTER_DIR/bin/flutter" ]; then
        print_info "Downloading Flutter SDK $FLUTTER_VERSION for $OS-$ARCH..."

        # Construct download URL
        if [ "$OS" = "linux" ]; then
            FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/${OS}/flutter_${OS}_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.tar.xz"
            ARCHIVE_EXT="tar.xz"
        elif [ "$OS" = "macos" ]; then
            if [ "$ARCH" = "arm64" ]; then
                FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/${OS}/flutter_${OS}_arm64_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.zip"
            else
                FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/${OS}/flutter_${OS}_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.zip"
            fi
            ARCHIVE_EXT="zip"
        elif [ "$OS" = "windows" ]; then
            FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/${OS}/flutter_${OS}_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.zip"
            ARCHIVE_EXT="zip"
        else
            print_error "Unsupported OS: $OS"
            exit 1
        fi

        ARCHIVE_FILE="/tmp/flutter_sdk.$ARCHIVE_EXT"

        print_info "Download URL: $FLUTTER_URL"
        $DOWNLOAD_CMD "$ARCHIVE_FILE" "$FLUTTER_URL"

        print_info "Extracting Flutter SDK..."
        mkdir -p "$FLUTTER_DIR"

        if [ "$ARCHIVE_EXT" = "tar.xz" ]; then
            tar -xf "$ARCHIVE_FILE" -C "$(dirname "$FLUTTER_DIR")"
            mv "$(dirname "$FLUTTER_DIR")/flutter" "$FLUTTER_DIR" 2>/dev/null || true
        else
            unzip -q "$ARCHIVE_FILE" -d "$(dirname "$FLUTTER_DIR")"
            mv "$(dirname "$FLUTTER_DIR")/flutter" "$FLUTTER_DIR" 2>/dev/null || true
        fi

        rm -f "$ARCHIVE_FILE"
        print_success "Flutter SDK extracted to $FLUTTER_DIR"
    fi

    FLUTTER_BIN="$FLUTTER_DIR/bin/flutter"
else
    # Use system Flutter
    if command -v flutter &> /dev/null; then
        FLUTTER_BIN="flutter"
        print_success "Using system Flutter: $(which flutter)"
    else
        print_error "Flutter not found in PATH. Please install Flutter or remove --skip-sdk flag."
        exit 1
    fi
fi

# ==============================================================================
# Flutter Configuration
# ==============================================================================

print_header "Configuring Flutter"

# Disable analytics
"$FLUTTER_BIN" config --no-analytics 2>/dev/null || true

# Enable web support
print_info "Enabling web support..."
"$FLUTTER_BIN" config --enable-web

if [ "$WEB_ONLY" = false ]; then
    # Enable other platforms based on OS
    if [ "$OS" = "linux" ]; then
        print_info "Enabling Linux desktop support..."
        "$FLUTTER_BIN" config --enable-linux-desktop
    elif [ "$OS" = "macos" ]; then
        print_info "Enabling macOS desktop support..."
        "$FLUTTER_BIN" config --enable-macos-desktop
    elif [ "$OS" = "windows" ]; then
        print_info "Enabling Windows desktop support..."
        "$FLUTTER_BIN" config --enable-windows-desktop
    fi
fi

# Run flutter doctor
print_header "Running Flutter Doctor"
"$FLUTTER_BIN" doctor -v || true

# ==============================================================================
# Flutter App Setup
# ==============================================================================

print_header "Setting up Flutter App"

if [ ! -d "$FLUTTER_APP_DIR" ]; then
    print_error "Flutter app directory not found at $FLUTTER_APP_DIR"
    exit 1
fi

cd "$FLUTTER_APP_DIR"

# Get dependencies
print_info "Getting Flutter dependencies..."
"$FLUTTER_BIN" pub get

print_success "Dependencies installed"

# ==============================================================================
# Build Instructions
# ==============================================================================

print_header "Setup Complete!"

echo ""
echo -e "${GREEN}Flutter SDK is ready!${NC}"
echo ""
echo "To use this Flutter installation, either:"
echo ""
echo "  1. Add to your PATH (temporary):"
echo -e "     ${YELLOW}export PATH=\"$FLUTTER_DIR/bin:\$PATH\"${NC}"
echo ""
echo "  2. Add to your shell profile (~/.bashrc or ~/.zshrc):"
echo -e "     ${YELLOW}echo 'export PATH=\"$FLUTTER_DIR/bin:\$PATH\"' >> ~/.bashrc${NC}"
echo ""
echo "To run the app:"
echo ""
echo -e "  ${BLUE}Web (recommended for development):${NC}"
echo -e "     ${YELLOW}cd $FLUTTER_APP_DIR${NC}"
echo -e "     ${YELLOW}$FLUTTER_BIN run -d chrome${NC}"
echo ""
echo -e "  ${BLUE}Or use the project start script:${NC}"
echo -e "     ${YELLOW}./start_project.sh${NC}"
echo ""

if [ "$WEB_ONLY" = false ]; then
    echo -e "  ${BLUE}Linux Desktop:${NC}"
    echo -e "     ${YELLOW}$FLUTTER_BIN run -d linux${NC}"
    echo ""
fi

echo -e "  ${BLUE}Build for production:${NC}"
echo -e "     ${YELLOW}$FLUTTER_BIN build web${NC}"
echo ""

# Create a convenience script
cat > "$SCRIPT_DIR/run_flutter.sh" << EOF
#!/bin/bash
# Convenience script to run Flutter commands with the local SDK

export PATH="$FLUTTER_DIR/bin:\$PATH"

if [ \$# -eq 0 ]; then
    echo "Usage: ./run_flutter.sh <flutter-command>"
    echo "Example: ./run_flutter.sh run -d chrome"
    echo "         ./run_flutter.sh build web"
    echo "         ./run_flutter.sh doctor"
    exit 1
fi

cd "$FLUTTER_APP_DIR"
flutter "\$@"
EOF

chmod +x "$SCRIPT_DIR/run_flutter.sh"

print_success "Created convenience script: ./run_flutter.sh"
echo ""
echo -e "Quick start: ${YELLOW}./run_flutter.sh run -d chrome${NC}"
echo ""
