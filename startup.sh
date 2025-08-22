#!/bin/bash

# DCMTK FindSCU Docker Setup Script
# This script sets up and starts the DCMTK FindSCU environment

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Docker installation
check_docker() {
    print_status "Checking Docker installation..."
    
    if ! command_exists docker; then
        print_error "Docker is not installed. Please install Docker first."
        print_status "Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    print_success "Docker is installed"
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
    
    print_success "Docker daemon is running"
}

# Function to check Docker Compose
check_docker_compose() {
    print_status "Checking Docker Compose..."
    
    if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
        print_error "Docker Compose is not available."
        exit 1
    fi
    
    print_success "Docker Compose is available"
}

# Function to create required directories
create_directories() {
    print_status "Creating required directories..."
    
    local dirs=("scripts" "queries" "results" "config" "tools" "logs" "web")
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            print_success "Created directory: $dir"
        else
            print_status "Directory already exists: $dir"
        fi
    done
}

# Function to check environment file
check_env_file() {
    print_status "Checking environment configuration..."
    
    if [ ! -f "$ENV_FILE" ]; then
        print_warning "Environment file '$ENV_FILE' not found"
        print_status "Creating default environment file..."
        
        cat > "$ENV_FILE" << 'EOF'
# DCMTK FindSCU Configuration
PACS_HOST=localhost
PACS_PORT=4242
REMOTE_AET=ORTHANC
LOCAL_AET=FINDSCU
LOCAL_PORT=11112
WEB_PORT=8080
LOG_LEVEL=INFO
LOG_DIR=./logs
QUERY_TIMEOUT=30
MAX_RESULTS=100
NETWORK_TIMEOUT=30
ACSE_TIMEOUT=30
OUTPUT_FORMAT=json
RESULT_DIR=./results
EOF
        print_success "Created default environment file"
    else
        print_success "Environment file found"
    fi
}

# Function to create sample scripts
create_sample_scripts() {
    print_status "Creating sample scripts..."
    
    # Create worklist query script
    cat > "scripts/query-worklist.sh" << 'EOF'
#!/bin/bash
# Query DICOM Modality Worklist

PACS_HOST=${PACS_HOST:-localhost}
PACS_PORT=${PACS_PORT:-4242}
LOCAL_AET=${LOCAL_AET:-FINDSCU}
REMOTE_AET=${REMOTE_AET:-ORTHANC}

echo "Querying Modality Worklist from $PACS_HOST:$PACS_PORT"

findscu \
    -v \
    -aet "$LOCAL_AET" \
    -aec "$REMOTE_AET" \
    -P \
    -k "ScheduledProcedureStepSequence[0].Modality" \
    -k "ScheduledProcedureStepSequence[0].ScheduledStationAETitle" \
    -k "ScheduledProcedureStepSequence[0].ScheduledProcedureStepStartDate" \
    -k "ScheduledProcedureStepSequence[0].ScheduledProcedureStepStartTime" \
    -k "PatientName" \
    -k "PatientID" \
    -k "AccessionNumber" \
    "$PACS_HOST" "$PACS_PORT"
EOF

    # Create patient query script
    cat > "scripts/query-patient.sh" << 'EOF'
#!/bin/bash
# Query DICOM Patient Information

PACS_HOST=${PACS_HOST:-localhost}
PACS_PORT=${PACS_PORT:-4242}
LOCAL_AET=${LOCAL_AET:-FINDSCU}
REMOTE_AET=${REMOTE_AET:-ORTHANC}
PATIENT_NAME=${1:-"*"}

echo "Querying patient information for: $PATIENT_NAME"

findscu \
    -v \
    -aet "$LOCAL_AET" \
    -aec "$REMOTE_AET" \
    -P \
    -k "QueryRetrieveLevel=PATIENT" \
    -k "PatientName=$PATIENT_NAME" \
    -k "PatientID" \
    -k "PatientBirthDate" \
    -k "PatientSex" \
    "$PACS_HOST" "$PACS_PORT"
EOF

    # Create study query script
    cat > "scripts/query-study.sh" << 'EOF'
#!/bin/bash
# Query DICOM Study Information

PACS_HOST=${PACS_HOST:-localhost}
PACS_PORT=${PACS_PORT:-4242}
LOCAL_AET=${LOCAL_AET:-FINDSCU}
REMOTE_AET=${REMOTE_AET:-ORTHANC}
PATIENT_ID=${1:-"*"}

echo "Querying studies for patient: $PATIENT_ID"

findscu \
    -v \
    -aet "$LOCAL_AET" \
    -aec "$REMOTE_AET" \
    -S \
    -k "QueryRetrieveLevel=STUDY" \
    -k "PatientID=$PATIENT_ID" \
    -k "StudyInstanceUID" \
    -k "StudyDescription" \
    -k "StudyDate" \
    -k "StudyTime" \
    -k "AccessionNumber" \
    "$PACS_HOST" "$PACS_PORT"
EOF

    chmod +x scripts/*.sh
    print_success "Created sample query scripts"
}

# Function to create nginx configuration
create_nginx_config() {
    print_status "Creating nginx configuration..."
    
    cat > "nginx.conf" << 'EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    server {
        listen 80;
        server_name localhost;
        
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
        
        location /api/query {
            proxy_pass http://dcmtk-findscu:8000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
EOF

    print_success "Created nginx configuration"
}

# Function to create simple web interface
create_web_interface() {
    print_status "Creating web interface..."
    
    cat > "web/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DCMTK FindSCU Interface</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .container { max-width: 800px; margin: 0 auto; }
        .query-form { background: #f5f5f5; padding: 20px; border-radius: 5px; margin: 20px 0; }
        .result { background: #e8f5e8; padding: 15px; border-radius: 5px; margin: 10px 0; }
        input, select, button { padding: 8px; margin: 5px; }
        button { background: #007cba; color: white; border: none; cursor: pointer; }
        button:hover { background: #005a8b; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔍 DCMTK FindSCU Interface</h1>
        <p>DICOM Modality Worklist and Patient Query Tool</p>
        
        <div class="query-form">
            <h3>Query Modality Worklist</h3>
            <button onclick="queryWorklist()">Query All Worklists</button>
            <div id="worklist-results"></div>
        </div>
        
        <div class="query-form">
            <h3>Patient Query</h3>
            <input type="text" id="patient-name" placeholder="Patient Name (* for all)">
            <button onclick="queryPatient()">Search Patient</button>
            <div id="patient-results"></div>
        </div>
        
        <div class="query-form">
            <h3>Study Query</h3>
            <input type="text" id="patient-id" placeholder="Patient ID">
            <button onclick="queryStudy()">Search Studies</button>
            <div id="study-results"></div>
        </div>
    </div>

    <script>
        function queryWorklist() {
            document.getElementById('worklist-results').innerHTML = '<p>Querying worklist...</p>';
            // Add AJAX call to backend when implemented
            setTimeout(() => {
                document.getElementById('worklist-results').innerHTML = 
                    '<div class="result">Sample worklist query results would appear here</div>';
            }, 1000);
        }
        
        function queryPatient() {
            const patientName = document.getElementById('patient-name').value || '*';
            document.getElementById('patient-results').innerHTML = '<p>Searching patients...</p>';
            // Add AJAX call to backend when implemented
            setTimeout(() => {
                document.getElementById('patient-results').innerHTML = 
                    '<div class="result">Patient search results for "' + patientName + '" would appear here</div>';
            }, 1000);
        }
        
        function queryStudy() {
            const patientId = document.getElementById('patient-id').value;
            if (!patientId) {
                alert('Please enter a Patient ID');
                return;
            }
            document.getElementById('study-results').innerHTML = '<p>Searching studies...</p>';
            // Add AJAX call to backend when implemented
            setTimeout(() => {
                document.getElementById('study-results').innerHTML = 
                    '<div class="result">Study search results for patient "' + patientId + '" would appear here</div>';
            }, 1000);
        }
    </script>
</body>
</html>
EOF

    print_success "Created web interface"
}

# Function to start containers
start_containers() {
    print_status "Starting DCMTK containers..."
    
    # Pull images first
    docker-compose pull
    
    # Start containers
    docker-compose up -d
    
    if [ $? -eq 0 ]; then
        print_success "Containers started successfully"
    else
        print_error "Failed to start containers"
        exit 1
    fi
}

# Function to verify containers are running
verify_containers() {
    print_status "Verifying container status..."
    
    sleep 3
    
    local containers=("dcmtk-findscu-client" "dcmtk-tools-server" "dcmtk-web-interface")
    
    for container in "${containers[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "$container"; then
            print_success "Container $container is running"
        else
            print_warning "Container $container may not be running"
        fi
    done
}

# Function to display connection information
display_connection_info() {
    print_success "=== DCMTK FindSCU Setup Complete ==="
    echo
    print_status "Web Interface: http://localhost:${WEB_PORT:-8080}"
    print_status "PACS Server: ${PACS_HOST:-localhost}:${PACS_PORT:-4242}"
    print_status "Local AET: ${LOCAL_AET:-FINDSCU}"
    print_status "Remote AET: ${REMOTE_AET:-ORTHANC}"
    echo
    print_status "Useful commands:"
    echo "  Execute queries:     docker-compose exec dcmtk-findscu bash"
    echo "  View logs:          docker-compose logs -f"
    echo "  Stop containers:    docker-compose down"
    echo "  Restart:            docker-compose restart"
    echo
    print_status "Sample queries:"
    echo "  Query worklist:     docker-compose exec dcmtk-findscu ./query-worklist.sh"
    echo "  Query patient:      docker-compose exec dcmtk-findscu ./query-patient.sh 'DOE^JOHN'"
    echo "  Query study:        docker-compose exec dcmtk-findscu ./query-study.sh P123456"
}

# Function to handle cleanup on script exit
cleanup() {
    if [ $? -ne 0 ]; then
        print_error "Script failed. Check the error messages above."
        print_status "You can clean up with: docker-compose down"
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Main execution
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}    DCMTK FindSCU Docker Setup         ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
    
    check_docker
    check_docker_compose
    create_directories
    check_env_file
    create_sample_scripts
    create_nginx_config
    create_web_interface
    start_containers
    verify_containers
    display_connection_info
    
    print_success "Setup completed successfully!"
}

# Run main function
main "$@"
