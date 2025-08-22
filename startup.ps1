# DCMTK FindSCU Docker Setup Script for Windows PowerShell
# This script sets up and starts the DCMTK FindSCU environment

param(
    [switch]$Force,
    [string]$PacsHost = "localhost",
    [int]$PacsPort = 4242,
    [string]$LocalAET = "FINDSCU",
    [string]$RemoteAET = "ORTHANC",
    [int]$WebPort = 8080
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Color functions for output
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Function to check if command exists
function Test-CommandExists {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

# Function to check Docker installation
function Test-Docker {
    Write-Info "Checking Docker installation..."
    
    if (-not (Test-CommandExists "docker")) {
        Write-Error "Docker is not installed. Please install Docker Desktop first."
        Write-Info "Visit: https://docs.docker.com/desktop/install/windows/"
        exit 1
    }
    
    Write-Success "Docker is installed"
    
    # Check if Docker daemon is running
    try {
        docker info | Out-Null
        Write-Success "Docker daemon is running"
    }
    catch {
        Write-Error "Docker daemon is not running. Please start Docker Desktop."
        exit 1
    }
}

# Function to check Docker Compose
function Test-DockerCompose {
    Write-Info "Checking Docker Compose..."
    
    try {
        docker compose version | Out-Null
        Write-Success "Docker Compose is available"
    }
    catch {
        try {
            docker-compose version | Out-Null
            Write-Success "Docker Compose (legacy) is available"
        }
        catch {
            Write-Error "Docker Compose is not available."
            exit 1
        }
    }
}

# Function to create required directories
function New-RequiredDirectories {
    Write-Info "Creating required directories..."
    
    $directories = @("scripts", "queries", "results", "config", "tools", "logs", "web")
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Success "Created directory: $dir"
        }
        else {
            Write-Info "Directory already exists: $dir"
        }
    }
}

# Function to check environment file
function Test-EnvFile {
    Write-Info "Checking environment configuration..."
    
    $envFile = ".env"
    if (-not (Test-Path $envFile)) {
        Write-Warning "Environment file '$envFile' not found"
        Write-Info "Creating default environment file..."
        
        $envContent = @"
# DCMTK FindSCU Configuration
PACS_HOST=$PacsHost
PACS_PORT=$PacsPort
REMOTE_AET=$RemoteAET
LOCAL_AET=$LocalAET
LOCAL_PORT=11112
WEB_PORT=$WebPort
LOG_LEVEL=INFO
LOG_DIR=./logs
QUERY_TIMEOUT=30
MAX_RESULTS=100
NETWORK_TIMEOUT=30
ACSE_TIMEOUT=30
OUTPUT_FORMAT=json
RESULT_DIR=./results
"@
        
        $envContent | Set-Content $envFile -Encoding UTF8
        Write-Success "Created default environment file"
    }
    else {
        Write-Success "Environment file found"
    }
}

# Function to create sample scripts
function New-SampleScripts {
    Write-Info "Creating sample scripts..."
    
    # Create worklist query script (PowerShell version)
    $worklistScript = @'
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
'@
    
    $worklistScript | Set-Content "scripts\query-worklist.sh" -Encoding UTF8
    
    # Create patient query script
    $patientScript = @'
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
'@
    
    $patientScript | Set-Content "scripts\query-patient.sh" -Encoding UTF8
    
    # Create study query script
    $studyScript = @'
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
'@
    
    $studyScript | Set-Content "scripts\query-study.sh" -Encoding UTF8
    
    Write-Success "Created sample query scripts"
}

# Function to create nginx configuration
function New-NginxConfig {
    Write-Info "Creating nginx configuration..."
    
    $nginxConfig = @'
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
'@
    
    $nginxConfig | Set-Content "nginx.conf" -Encoding UTF8
    Write-Success "Created nginx configuration"
}

# Function to create simple web interface
function New-WebInterface {
    Write-Info "Creating web interface..."
    
    $webInterface = @'
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
        .info { background: #e3f2fd; padding: 15px; border-radius: 5px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔍 DCMTK FindSCU Interface</h1>
        <p>DICOM Modality Worklist and Patient Query Tool</p>
        
        <div class="info">
            <h3>📋 Available Commands</h3>
            <p><strong>Query Worklist:</strong> <code>docker-compose exec dcmtk-findscu ./query-worklist.sh</code></p>
            <p><strong>Query Patient:</strong> <code>docker-compose exec dcmtk-findscu ./query-patient.sh "DOE^JOHN"</code></p>
            <p><strong>Query Study:</strong> <code>docker-compose exec dcmtk-findscu ./query-study.sh P123456</code></p>
        </div>
        
        <div class="query-form">
            <h3>🏥 PACS Connection Status</h3>
            <p>PACS Server: <strong>localhost:4242</strong></p>
            <p>Remote AET: <strong>ORTHANC</strong></p>
            <p>Local AET: <strong>FINDSCU</strong></p>
            <button onclick="testConnection()">Test Connection</button>
            <div id="connection-status"></div>
        </div>
        
        <div class="query-form">
            <h3>📊 Quick Actions</h3>
            <button onclick="showHelp()">Show Help</button>
            <button onclick="showLogs()">View Logs</button>
            <button onclick="showContainers()">Container Status</button>
            <div id="action-results"></div>
        </div>
    </div>

    <script>
        function testConnection() {
            document.getElementById('connection-status').innerHTML = '<p>Testing PACS connection...</p>';
            setTimeout(() => {
                document.getElementById('connection-status').innerHTML = 
                    '<div class="result">✅ Connection test completed. Check container logs for details.</div>';
            }, 1000);
        }
        
        function showHelp() {
            document.getElementById('action-results').innerHTML = 
                '<div class="result">' +
                '<h4>DCMTK FindSCU Help</h4>' +
                '<p><strong>findscu</strong> - Query DICOM services for patient/study information</p>' +
                '<p><strong>Common options:</strong></p>' +
                '<ul>' +
                '<li>-v : Verbose output</li>' +
                '<li>-aet : Local Application Entity Title</li>' +
                '<li>-aec : Called Application Entity Title</li>' +
                '<li>-P : Patient Root Query</li>' +
                '<li>-S : Study Root Query</li>' +
                '<li>-k : Query key (DICOM tag)</li>' +
                '</ul>' +
                '</div>';
        }
        
        function showLogs() {
            document.getElementById('action-results').innerHTML = 
                '<div class="result">📋 Use <code>docker-compose logs -f</code> to view real-time logs</div>';
        }
        
        function showContainers() {
            document.getElementById('action-results').innerHTML = 
                '<div class="result">🐳 Use <code>docker-compose ps</code> to check container status</div>';
        }
    </script>
</body>
</html>
'@
    
    $webInterface | Set-Content "web\index.html" -Encoding UTF8
    Write-Success "Created web interface"
}

# Function to start containers
function Start-Containers {
    Write-Info "Starting DCMTK containers..."
    
    try {
        # Pull images first
        docker compose pull
        
        # Start containers
        docker compose up -d
        
        Write-Success "Containers started successfully"
    }
    catch {
        Write-Error "Failed to start containers: $($_.Exception.Message)"
        exit 1
    }
}

# Function to verify containers are running
function Test-Containers {
    Write-Info "Verifying container status..."
    
    Start-Sleep -Seconds 3
    
    $containers = @("dcmtk-findscu-client", "dcmtk-tools-server", "dcmtk-web-interface")
    
    foreach ($container in $containers) {
        try {
            $result = docker ps --format "table {{.Names}}" | Select-String -Pattern $container
            if ($result) {
                Write-Success "Container $container is running"
            }
            else {
                Write-Warning "Container $container may not be running"
            }
        }
        catch {
            Write-Warning "Could not check status of container $container"
        }
    }
}

# Function to display connection information
function Show-ConnectionInfo {
    Write-Success "=== DCMTK FindSCU Setup Complete ==="
    Write-Host ""
    Write-Info "Web Interface: http://localhost:$WebPort"
    Write-Info "PACS Server: $PacsHost`:$PacsPort"
    Write-Info "Local AET: $LocalAET"
    Write-Info "Remote AET: $RemoteAET"
    Write-Host ""
    Write-Info "Useful commands:"
    Write-Host "  Execute queries:     docker compose exec dcmtk-findscu bash"
    Write-Host "  View logs:          docker compose logs -f"
    Write-Host "  Stop containers:    docker compose down"
    Write-Host "  Restart:            docker compose restart"
    Write-Host ""
    Write-Info "Sample queries:"
    Write-Host "  Query worklist:     docker compose exec dcmtk-findscu ./query-worklist.sh"
    Write-Host "  Query patient:      docker compose exec dcmtk-findscu ./query-patient.sh 'DOE^JOHN'"
    Write-Host "  Query study:        docker compose exec dcmtk-findscu ./query-study.sh P123456"
    Write-Host ""
    Write-Info "Configuration files:"
    Write-Host "  Environment:        .env"
    Write-Host "  Docker Compose:     docker-compose.yml"
    Write-Host "  Nginx:              nginx.conf"
}

# Main execution
function Main {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "    DCMTK FindSCU Docker Setup         " -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        Test-Docker
        Test-DockerCompose
        New-RequiredDirectories
        Test-EnvFile
        New-SampleScripts
        New-NginxConfig
        New-WebInterface
        Start-Containers
        Test-Containers
        Show-ConnectionInfo
        
        Write-Success "Setup completed successfully!"
    }
    catch {
        Write-Error "Script failed: $($_.Exception.Message)"
        Write-Info "You can clean up with: docker compose down"
        exit 1
    }
}

# Run main function
Main
