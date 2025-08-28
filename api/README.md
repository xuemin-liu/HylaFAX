# HylaFAX API Documentation

This directory contains API wrappers for HylaFAX that provide programmatic access to fax sending and status checking functionality without requiring command execution.

## Components

### 1. C++ API Library (`FaxAPI.h` / `FaxAPI.cpp`)
Core C++ library that wraps the HylaFAX client libraries.

**Features:**
- Send faxes with full option control
- Check job status across all queues
- Job management (kill, suspend, resume, wait)
- Direct access to HylaFAX protocol without command execution

**Usage:**
```cpp
#include "FaxAPI.h"

FaxAPI faxApi("localhost");
std::string errorMsg;

// Connect and login
if (faxApi.connect(errorMsg) && faxApi.login("", errorMsg)) {
    // Send fax
    FaxAPI::FaxSendOptions options;
    options.coverComments = "Test fax";
    options.useECM = true;
    
    auto result = faxApi.sendFax({"document.pdf"}, {"555-1234"}, options);
    if (result.success) {
        std::cout << "Job ID: " << result.jobId << std::endl;
    }
    
    // Check status
    auto jobs = faxApi.getJobStatus(FaxAPI::SEND_QUEUE);
    for (const auto& job : jobs) {
        std::cout << "Job " << job.jobId << ": " << job.state << std::endl;
    }
}
```

### 2. Python Wrapper (`pyfax.py`)
Python bindings using ctypes to access the C++ library.

**Usage:**
```python
from pyfax import PyFaxAPI, QueueType

with PyFaxAPI("localhost") as fax_api:
    # Connect and login
    fax_api.connect()
    fax_api.login()
    
    # Send fax
    result = fax_api.send_fax(
        files=['document.pdf'],
        destinations=['555-1234'],
        options={'coverComments': 'Test fax', 'useECM': True}
    )
    
    if result['success']:
        print(f"Job ID: {result['job_id']}")
    
    # Check status
    jobs = fax_api.get_job_status(QueueType.SEND_QUEUE)
    for job in jobs:
        print(f"Job {job['job_id']}: {job['state']}")
```

### 3. REST API (`rest_api.py`)
Flask-based REST API providing HTTP endpoints.

**Endpoints:**

#### Health Check
```
GET /api/health
```

#### Send Fax
```
POST /api/fax/send
Content-Type: multipart/form-data

files: file(s) to send
destinations: JSON array of phone numbers
options: JSON object with fax options (optional)
```

Example:
```bash
curl -X POST http://localhost:5000/api/fax/send \
  -F "files=@document.pdf" \
  -F 'destinations=["555-1234", "555-5678"]' \
  -F 'options={"coverComments": "Test fax", "useECM": true}'
```

#### Get Status
```
GET /api/fax/status?queue=send
```

Queue types: `send`, `done`, `recv`, `archive`, `document`, `server`

#### Job Management
```
GET /api/fax/job/{job_id}           # Get job info
POST /api/fax/job/{job_id}/kill     # Kill job
POST /api/fax/job/{job_id}/suspend  # Suspend job
POST /api/fax/job/{job_id}/resume   # Resume job
POST /api/fax/job/{job_id}/wait     # Wait for completion
```

## Building

### C++ Library
```bash
cd api
make -f Makefile.in
```

### Python Dependencies
```bash
pip install flask werkzeug
```

### Running REST API
```bash
export HYLAFAX_HOST=localhost
export UPLOAD_FOLDER=/tmp/fax_uploads
python rest_api.py
```

## Configuration Options

### FaxSendOptions
Available options for sending faxes:

- `recipient`: Recipient name
- `coverComments`: Cover page comments
- `coverRegarding`: Cover page regarding field
- `coverFromVoice`: Sender's voice number
- `coverFromFax`: Sender's fax number
- `coverFromCompany`: Sender's company
- `coverTemplate`: Cover page template file
- `jobTag`: User job identifier
- `tsi`: Transmitting Station ID
- `sendTime`: Scheduled send time
- `killTime`: Job expiration time
- `retryTime`: Retry interval
- `pageSize`: Page size (letter, a4, etc.)
- `notification`: Notification type (none, done, requeued)
- `priority`: Job priority (normal, bulk, high)
- `vResolution`: Vertical resolution (98.0 for low, 196.0 for high)
- `maxRetries`: Maximum retry attempts
- `maxDials`: Maximum dial attempts
- `autoCoverPage`: Generate cover page (true/false)
- `useECM`: Use error correction mode (true/false)
- `useXVRes`: Use extended resolutions (true/false)
- `archive`: Archive completed job (true/false)
- `desiredSpeed`: Desired transmission speed (bps)
- `minSpeed`: Minimum acceptable speed (bps)
- `desiredDataFormat`: Data format (0=1D, 1=2D, 3=MMR)

### Queue Types
- `SEND_QUEUE`: Jobs waiting to be sent
- `DONE_QUEUE`: Completed jobs
- `RECV_QUEUE`: Received faxes
- `ARCHIVE_QUEUE`: Archived jobs
- `DOCUMENT_QUEUE`: Queued documents
- `SERVER_STATUS`: Server/modem status

## Error Handling

All APIs return structured error information:
- C++: Boolean return values with error messages in output parameters
- Python: Tuples with (success, error_message) or dictionaries with error fields
- REST: JSON responses with success/error status and descriptive messages

## Advantages over Command Execution

1. **Performance**: Direct library access eliminates process spawning overhead
2. **Integration**: Structured data return instead of parsing command output
3. **Error Handling**: Detailed error information with proper error codes
4. **Security**: No shell command injection vulnerabilities
5. **Flexibility**: Full programmatic control over all HylaFAX features
6. **Reliability**: Type-safe interfaces reduce runtime errors

## Requirements

- HylaFAX server running and accessible
- HylaFAX client libraries installed
- For Python wrapper: Python 3.6+ with ctypes
- For REST API: Flask and dependencies
- Appropriate permissions for fax operations

## Security Considerations

- REST API should be secured with authentication in production
- File uploads are limited in size and type
- Temporary files are cleaned up automatically
- Input validation prevents injection attacks
- Consider running behind a reverse proxy with HTTPS
