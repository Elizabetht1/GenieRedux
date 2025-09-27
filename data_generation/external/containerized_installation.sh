#!/bin/bash


# CURRENTLY FAILING L

# Coinrun setup for systems with restricted permissions
set -euo pipefail

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_PATH"

echo "=== COINRUN SETUP FOR RESTRICTED SYSTEMS ==="

# Check if we can run Docker at all
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Cannot proceed without Docker."
    echo "Please contact your system administrator to install Docker."
    exit 1
fi

# Detect architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]] || [[ "$ARCH" == "aarch64" ]]; then
    DOCKER_PLATFORM="--platform linux/amd64"
    echo "ARM64 detected - using x86_64 emulation"
else
    DOCKER_PLATFORM=""
    echo "x86_64 detected - using native build"
fi

# Determine Docker command
if docker ps &> /dev/null 2>&1; then
    DOCKER_CMD="docker"
    echo "Docker access: OK"
elif sudo docker ps &> /dev/null 2>&1; then
    DOCKER_CMD="sudo docker"
    echo "Docker access: Requires sudo"
else
    echo "Cannot access Docker. Trying to diagnose..."
    echo ""
    echo "Diagnosis steps:"
    echo "1. Check if Docker daemon is running:"
    echo "   systemctl status docker"
    echo ""
    echo "2. Check if you're in docker group:"
    echo "   groups | grep docker"
    echo ""
    echo "3. If not in docker group, ask admin to run:"
    echo "   sudo usermod -aG docker $(whoami)"
    echo "   # Then log out and back in"
    echo ""
    echo "4. Try simple Docker test:"
    echo "   docker run hello-world"
    exit 1
fi

# Alternative approach: Use pre-built image if available
echo "Checking for alternative installation methods..."

# Method 1: Try to pull a pre-built coinrun image (if available)
echo "Attempting to use pre-built coinrun image..."
if $DOCKER_CMD pull $DOCKER_PLATFORM openai/coinrun:latest 2>/dev/null; then
    echo "Found pre-built coinrun image"
    COINRUN_IMAGE="openai/coinrun:latest"
    SKIP_BUILD=true
elif $DOCKER_CMD pull $DOCKER_PLATFORM tensorflow/tensorflow:1.12.0-py3 2>/dev/null; then
    echo "Found TensorFlow base image - will build minimal coinrun"
    SKIP_BUILD=false
else
    echo "No pre-built images available"
    SKIP_BUILD=false
fi

if [ "$SKIP_BUILD" = false ]; then
    # Method 2: Create custom Dockerfile that doesn't require apt-get updates
    echo "Creating custom Dockerfile without system updates..."
    
    # Clone coinrun
    if [ -d "coinrun" ]; then
        rm -rf coinrun
    fi
    git clone https://github.com/openai/coinrun.git
    cd coinrun
    
    # Copy your files
    if [ -f "$SCRIPT_PATH/random_agent.py" ]; then
        cp "$SCRIPT_PATH/random_agent.py" "$SCRIPT_PATH/coinrun/coinrun/"
    fi
    
    # Create a modified Dockerfile that works without apt-get permissions
    cat > Dockerfile.restricted << 'EOF'
FROM tensorflow/tensorflow:1.12.0-py3

# Set working directory
WORKDIR /app

# Copy coinrun files
COPY . .

# Install Python dependencies without system packages
RUN pip install --upgrade pip
RUN pip install gym[atari]==0.10.11
RUN pip install opencv-python-headless  # Headless version doesn't need system libs
RUN pip install matplotlib pandas scipy numpy tqdm
RUN pip install -e .

# Set environment variables
ENV PYTHONPATH=/app:$PYTHONPATH

# Default command
CMD ["/bin/bash"]
EOF
    
    echo "Building coinrun with restricted Dockerfile..."
    COINRUN_IMAGE="coinrun-restricted"
    if $DOCKER_CMD build $DOCKER_PLATFORM -f Dockerfile.restricted -t "$COINRUN_IMAGE" .; then
        echo "Restricted build successful"
    else
        echo "Restricted build failed. Trying minimal approach..."
        
        # Method 3: Ultra-minimal approach
        cat > Dockerfile.minimal << 'EOF'
FROM python:3.6-slim

WORKDIR /app
COPY . .

# Install only what we absolutely need
RUN pip install --no-cache-dir tensorflow==1.12.0
RUN pip install --no-cache-dir gym==0.10.11
RUN pip install --no-cache-dir numpy scipy
RUN pip install --no-cache-dir -e .

CMD ["/bin/bash"]
EOF
        
        if $DOCKER_CMD build $DOCKER_PLATFORM -f Dockerfile.minimal -t "$COINRUN_IMAGE" .; then
            echo "Minimal build successful"
        else
            echo "All build methods failed."
            echo "This system may not support coinrun Docker installation."
            echo ""
            echo "Alternatives:"
            echo "1. Use a different machine with full Docker permissions"
            echo "2. Ask system administrator for help"
            echo "3. Use cloud development environment (GitHub Codespaces, etc.)"
            exit 1
        fi
    fi
else
    cd coinrun || { git clone https://github.com/openai/coinrun.git && cd coinrun; }
fi

# Test the installation
echo "Testing coinrun installation..."
if $DOCKER_CMD run --rm $DOCKER_PLATFORM "$COINRUN_IMAGE" python -c "import coinrun; print('Coinrun works!')"; then
    echo "SUCCESS! Coinrun is working."
    
    # Create wrapper scripts
    cat > "$SCRIPT_PATH/run_coinrun.sh" << EOF
#!/bin/bash
SCRIPT_PATH="\$(cd "\$(dirname "\$0")" && pwd)"
$DOCKER_CMD run --rm $DOCKER_PLATFORM -v "\$SCRIPT_PATH:/workspace" -w /workspace $COINRUN_IMAGE python "\$@"
EOF
    chmod +x "$SCRIPT_PATH/run_coinrun.sh"
    
    cat > "$SCRIPT_PATH/coinrun_shell.sh" << EOF
#!/bin/bash
SCRIPT_PATH="\$(cd "\$(dirname "\$0")" && pwd)"
echo "Starting coinrun shell (restricted system setup)..."
$DOCKER_CMD run --rm -it $DOCKER_PLATFORM -v "\$SCRIPT_PATH:/workspace" -w /workspace $COINRUN_IMAGE /bin/bash
EOF
    chmod +x "$SCRIPT_PATH/coinrun_shell.sh"
    
    echo ""
    echo "Coinrun is ready! Usage:"
    echo "./run_coinrun.sh your_script.py"
    echo "./coinrun_shell.sh  # for interactive session"
    
else
    echo "Coinrun test failed. The image was built but coinrun doesn't work."
    echo "This may be due to system restrictions or missing dependencies."
fi