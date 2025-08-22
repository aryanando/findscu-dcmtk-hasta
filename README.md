# DCMTK FindSCU Docker Environment

A Docker-based DICOM C-FIND client using DCMTK tools for querying PACS servers and modality worklists.

## Features

- 🐳 Docker containerized DCMTK tools
- 🔍 DICOM C-FIND operations for worklist queries
- 📋 Modality Worklist (MWL) support
- 🌐 Network connectivity to PACS servers
- 📝 Pre-configured query scripts

## Quick Start

1. **Clone and Setup**
   ```bash
   git clone <repository-url>
   cd findscu-dcmtk
   cp .env.example .env
   ```

2. **Configure Environment**
   Edit `.env` file with your PACS settings:
   ```env
   PACS_HOST=host.docker.internal
   PACS_PORT=4242
   PACS_AET=ORTHANC
   LOCAL_AET=FINDSCU
   ```

3. **Start Services**
   ```bash
   docker compose up -d
   ```

4. **Query Worklists**
   ```bash
   docker compose exec dcmtk-findscu ./query-worklist.sh
   ```

## Available Scripts

- `query-worklist.sh` - Query all available worklists
- `query-patient.sh` - Query specific patient information
- `test-connection.sh` - Test PACS connectivity

## Docker Services

- **dcmtk-findscu**: Ubuntu container with DCMTK tools installed
- **Networks**: Isolated Docker network for DICOM communication

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PACS_HOST` | PACS server hostname/IP | `host.docker.internal` |
| `PACS_PORT` | PACS server DICOM port | `4242` |
| `PACS_AET` | PACS Application Entity Title | `ORTHANC` |
| `LOCAL_AET` | Local Application Entity Title | `FINDSCU` |

### DICOM Tags Queried

**Worklist Query Tags:**
- `(0008,0050)` - Accession Number
- `(0010,0010)` - Patient Name
- `(0010,0020)` - Patient ID
- `(0008,0060)` - Modality
- `(0040,0001)` - Scheduled Station AE Title
- `(0040,0002)` - Scheduled Procedure Step Start Date
- `(0040,0003)` - Scheduled Procedure Step Start Time

## Integration

This DCMTK environment integrates with:
- **Orthanc PACS Server** - For modality worklist storage
- **Node.js REST API** - For programmatic access
- **SIM RS Hospital System** - For worklist management

## Troubleshooting

### Connection Issues
```bash
# Test PACS connectivity
docker compose exec dcmtk-findscu findscu -v -aet "FINDSCU" -aec "ORTHANC" host.docker.internal 4242

# Check container logs
docker compose logs dcmtk-findscu
```

### Network Issues
```bash
# Verify Docker network
docker network ls
docker network inspect findscu-dcmtk_findscu-network
```

## Development

### Adding New Queries
1. Create script in container: `/usr/local/bin/your-script.sh`
2. Make executable: `chmod +x /usr/local/bin/your-script.sh`
3. Test: `docker compose exec dcmtk-findscu ./your-script.sh`

### Debugging
```bash
# Interactive shell
docker compose exec dcmtk-findscu /bin/bash

# Verbose DICOM output
findscu -v -d -aet "FINDSCU" -aec "ORTHANC" host.docker.internal 4242
```

## License

MIT License - see LICENSE file for details.
