/*
 * HylaFAX API Implementation
 * Provides programmatic access to HylaFAX functionality without command execution
 */
#include "FaxAPI.h"
#include "SendFaxClient.h"
#include "FaxClient.h"
#include "Sys.h"
#include "NLS.h"
#include <sstream>
#include <fstream>

// Custom SendFaxClient for API use
class FaxAPI::SendFaxAPIClient : public SendFaxClient {
public:
    SendFaxAPIClient() : SendFaxClient() {}
    
    void initializeConfig() {
        resetConfig();
        readConfig(FAX_SYSCONF);
        readConfig(FAX_LIBDATA "/sendfax.conf");
        readConfig(FAX_USERCONF);
    }
    
    // Override notification methods to capture results instead of printing
    virtual void notifyNewJob(const SendFaxJob& job) override {
        lastJobId = getCurrentJob();
        // Store job info for API return
    }
    
    std::string getLastJobId() const { return lastJobId; }
    
private:
    std::string lastJobId;
};

// Custom FaxClient for status queries
class FaxAPI::StatusAPIClient : public FaxClient {
public:
    StatusAPIClient() : FaxClient() {}
    
    void initializeConfig() {
        resetConfig();
        readConfig(FAX_SYSCONF);
        readConfig(FAX_USERCONF);
    }
    
    bool getStatusData(const std::string& directory, std::vector<std::string>& lines, std::string& errorMsg) {
        if (!setMode(MODE_S)) {
            errorMsg = "Failed to set transfer mode";
            return false;
        }
        
        if (!initDataConn(errorMsg)) {
            return false;
        }
        
        if (command("LIST %s", directory.c_str()) != PRELIM) {
            errorMsg = "LIST command failed";
            return false;
        }
        
        if (!openDataConn(errorMsg)) {
            return false;
        }
        
        // Read data from connection
        std::string buffer;
        char readBuf[16 * 1024];
        int cc;
        
        while ((cc = read(getDataFd(), readBuf, sizeof(readBuf))) > 0) {
            buffer.append(readBuf, cc);
        }
        
        closeDataConn();
        
        if (getReply(false) != COMPLETE) {
            errorMsg = "Failed to complete LIST operation";
            return false;
        }
        
        // Parse buffer into lines
        std::istringstream stream(buffer);
        std::string line;
        while (std::getline(stream, line)) {
            if (!line.empty()) {
                lines.push_back(line);
            }
        }
        
        return true;
    }
};

// FaxSendOptions constructor with defaults
FaxAPI::FaxSendOptions::FaxSendOptions() 
    : vResolution(98.0f)    // low resolution default
    , maxRetries(3)
    , maxDials(12)
    , autoCoverPage(true)
    , useECM(true)
    , useXVRes(false)
    , archive(false)
    , desiredSpeed(14400)
    , minSpeed(2400)
    , desiredDataFormat(0)  // 1D encoding
    , notification("done")
    , priority("normal")
{
}

// FaxStatusOptions constructor
FaxAPI::FaxStatusOptions::FaxStatusOptions(QueueType type)
    : queueType(type)
    , useGMT(false)
    , showServerInfo(false)
{
}

// FaxAPI Implementation
FaxAPI::FaxAPI(const std::string& host)
    : sendClient(nullptr)
    , statusClient(nullptr)
    , hostName(host)
    , connected(false)
    , loggedIn(false)
{
    NLS::Setup("hylafax-client");
}

FaxAPI::~FaxAPI() {
    disconnect();
    cleanupClients();
}

bool FaxAPI::connect(std::string& errorMsg) {
    if (connected) {
        return true;
    }
    
    if (!initializeClients()) {
        errorMsg = "Failed to initialize clients";
        return false;
    }
    
    sendClient->setHost(hostName);
    statusClient->setHost(hostName);
    
    if (!sendClient->callServer(errorMsg)) {
        lastError = errorMsg;
        return false;
    }
    
    if (!statusClient->callServer(errorMsg)) {
        lastError = errorMsg;
        sendClient->hangupServer();
        return false;
    }
    
    connected = true;
    return true;
}

bool FaxAPI::disconnect() {
    if (!connected) {
        return true;
    }
    
    if (sendClient) {
        sendClient->hangupServer();
    }
    
    if (statusClient) {
        statusClient->hangupServer();
    }
    
    connected = false;
    loggedIn = false;
    return true;
}

bool FaxAPI::isConnected() const {
    return connected;
}

bool FaxAPI::login(const std::string& username, std::string& errorMsg) {
    if (!connected) {
        errorMsg = "Not connected to server";
        return false;
    }
    
    if (loggedIn) {
        return true;
    }
    
    const char* user = username.empty() ? nullptr : username.c_str();
    
    if (!sendClient->login(user, errorMsg)) {
        lastError = errorMsg;
        return false;
    }
    
    if (!statusClient->login(user, errorMsg)) {
        lastError = errorMsg;
        return false;
    }
    
    loggedIn = true;
    return true;
}

FaxSubmissionResult FaxAPI::sendFax(const std::vector<std::string>& files, 
                                   const std::vector<std::string>& destinations,
                                   const FaxSendOptions& options) {
    FaxSubmissionResult result;
    
    if (!connected || !loggedIn) {
        result.errorMessage = "Not connected or logged in";
        return result;
    }
    
    try {
        // Configure the prototype job
        SendFaxJob& proto = sendClient->getProtoJob();
        
        // Apply options to prototype job
        if (!options.coverComments.empty()) {
            proto.setCoverComments(options.coverComments);
        }
        if (!options.coverRegarding.empty()) {
            proto.setCoverRegarding(options.coverRegarding);
        }
        if (!options.coverFromVoice.empty()) {
            proto.setCoverFromVoice(options.coverFromVoice);
        }
        if (!options.coverFromFax.empty()) {
            proto.setCoverFromFax(options.coverFromFax);
        }
        if (!options.sendTime.empty()) {
            proto.setSendTime(options.sendTime);
        }
        if (!options.jobTag.empty()) {
            proto.setJobTag(options.jobTag);
        }
        if (!options.tsi.empty()) {
            proto.setTSI(options.tsi);
        }
        if (!options.killTime.empty()) {
            proto.setKillTime(options.killTime);
        }
        if (!options.retryTime.empty()) {
            proto.setRetryTime(options.retryTime);
        }
        if (!options.pageSize.empty()) {
            proto.setPageSize(options.pageSize);
        }
        if (!options.priority.empty()) {
            proto.setPriority(options.priority);
        }
        if (!options.notification.empty()) {
            proto.setNotification(options.notification);
        }
        
        // Set numeric options
        proto.setVResolution(options.vResolution);
        proto.setMaxRetries(options.maxRetries);
        proto.setMaxDials(options.maxDials);
        proto.setAutoCoverPage(options.autoCoverPage);
        proto.setDesiredEC(options.useECM);
        proto.setUseXVRes(options.useXVRes);
        proto.setDesiredSpeed(options.desiredSpeed);
        proto.setMinSpeed(options.minSpeed);
        proto.setDesiredDF(options.desiredDataFormat);
        
        if (options.archive) {
            proto.setDoneOp("archive");
        }
        
        // Add destinations
        for (const auto& dest : destinations) {
            std::string recipient, number, subaddr;
            recipient = parseDestination(dest, number, subaddr);
            
            SendFaxJob& job = sendClient->addJob();
            job.setDialString(number);
            job.setCoverName(recipient);
            job.setSubAddress(subaddr);
        }
        
        // Add files
        for (const auto& file : files) {
            sendClient->addFile(file);
        }
        
        // Prepare and submit jobs
        std::string errorMsg;
        if (!sendClient->prepareForJobSubmissions(errorMsg)) {
            result.errorMessage = errorMsg;
            return result;
        }
        
        if (!sendClient->submitJobs(errorMsg)) {
            result.errorMessage = errorMsg;
            return result;
        }
        
        // Get job information
        result.success = true;
        result.jobId = sendClient->getLastJobId();
        result.totalPages = sendClient->getTotalPages();
        
    } catch (const std::exception& e) {
        result.errorMessage = std::string("Exception: ") + e.what();
    }
    
    return result;
}

FaxSubmissionResult FaxAPI::sendFax(const std::vector<std::string>& files,
                                   const std::string& destination,
                                   const FaxSendOptions& options) {
    std::vector<std::string> destinations = { destination };
    return sendFax(files, destinations, options);
}

std::vector<FaxJobInfo> FaxAPI::getJobStatus(const FaxStatusOptions& options) {
    return getJobStatus(options.queueType);
}

std::vector<FaxJobInfo> FaxAPI::getJobStatus(QueueType queueType) {
    std::vector<FaxJobInfo> jobs;
    
    if (!connected || !loggedIn) {
        return jobs;
    }
    
    std::string directory;
    switch (queueType) {
        case SEND_QUEUE:
            directory = FAX_SENDDIR;
            statusClient->setJobStatusFormat("%-4j %1a %3l %2d %12.12o %-20.20e %4v %s");
            break;
        case DONE_QUEUE:
            directory = FAX_DONEDIR;
            statusClient->setJobStatusFormat("%-4j %1a %3l %2d %12.12o %-20.20e %4v %s");
            break;
        case RECV_QUEUE:
            directory = FAX_RECVDIR;
            statusClient->setRecvStatusFormat("%-18f %8p %4s %12.12t %-20.20e %5S %s");
            break;
        case ARCHIVE_QUEUE:
            directory = FAX_ARCHDIR;
            statusClient->setJobStatusFormat("%-4j %1a %3l %2d %12.12o %-20.20e %4v %s");
            break;
        case DOCUMENT_QUEUE:
            directory = FAX_DOCDIR;
            statusClient->setFileStatusFormat("%-18f %8p %1o %8s %12.12t %s");
            break;
        case SERVER_STATUS:
            directory = FAX_STATUSDIR;
            statusClient->setModemStatusFormat("%-14m %1s %5r %12.12t %-20.20h %s");
            break;
    }
    
    std::vector<std::string> lines;
    std::string errorMsg;
    
    if (statusClient->getStatusData(directory, lines, errorMsg)) {
        // Skip header line if present
        for (size_t i = (lines.size() > 0 && lines[0].find("JID") != std::string::npos) ? 1 : 0; 
             i < lines.size(); ++i) {
            FaxJobInfo job = parseJobLine(lines[i], queueType);
            if (!job.jobId.empty()) {
                jobs.push_back(job);
            }
        }
    }
    
    return jobs;
}

bool FaxAPI::killJob(const std::string& jobId, std::string& errorMsg) {
    if (!connected || !loggedIn) {
        errorMsg = "Not connected or logged in";
        return false;
    }
    
    return sendClient->jobKill(jobId.c_str());
}

bool FaxAPI::suspendJob(const std::string& jobId, std::string& errorMsg) {
    if (!connected || !loggedIn) {
        errorMsg = "Not connected or logged in";
        return false;
    }
    
    return sendClient->jobSuspend(jobId.c_str());
}

bool FaxAPI::resumeJob(const std::string& jobId, std::string& errorMsg) {
    if (!connected || !loggedIn) {
        errorMsg = "Not connected or logged in";
        return false;
    }
    
    return sendClient->jobSubmit(jobId.c_str());
}

bool FaxAPI::waitForJob(const std::string& jobId, std::string& errorMsg) {
    if (!connected || !loggedIn) {
        errorMsg = "Not connected or logged in";
        return false;
    }
    
    return sendClient->jobWait(jobId.c_str());
}

void FaxAPI::setHost(const std::string& host) {
    hostName = host;
    if (sendClient) sendClient->setHost(host);
    if (statusClient) statusClient->setHost(host);
}

void FaxAPI::setVerbose(bool verbose) {
    if (sendClient) sendClient->setVerbose(verbose);
    if (statusClient) statusClient->setVerbose(verbose);
}

std::string FaxAPI::getLastError() const {
    return lastError;
}

// Private helper methods
bool FaxAPI::initializeClients() {
    if (!sendClient) {
        sendClient = new SendFaxAPIClient();
        sendClient->initializeConfig();
    }
    
    if (!statusClient) {
        statusClient = new StatusAPIClient();
        statusClient->initializeConfig();
    }
    
    return sendClient && statusClient;
}

void FaxAPI::cleanupClients() {
    delete sendClient;
    delete statusClient;
    sendClient = nullptr;
    statusClient = nullptr;
}

std::string FaxAPI::parseDestination(const std::string& dest, std::string& number, std::string& subaddr) {
    std::string recipient;
    
    // Parse format: recipient@number#subaddress
    size_t atPos = dest.find('@');
    size_t hashPos = dest.find('#');
    
    if (atPos != std::string::npos) {
        recipient = dest.substr(0, atPos);
        number = dest.substr(atPos + 1, (hashPos != std::string::npos) ? hashPos - atPos - 1 : std::string::npos);
    } else {
        number = dest.substr(0, (hashPos != std::string::npos) ? hashPos : std::string::npos);
    }
    
    if (hashPos != std::string::npos) {
        subaddr = dest.substr(hashPos + 1);
    }
    
    return recipient;
}

FaxJobInfo FaxAPI::parseJobLine(const std::string& line, QueueType queueType) {
    FaxJobInfo job;
    
    // This is a simplified parser - in practice you'd want more robust parsing
    // based on the exact format strings used by HylaFAX
    std::istringstream iss(line);
    
    switch (queueType) {
        case SEND_QUEUE:
        case DONE_QUEUE:
        case ARCHIVE_QUEUE:
            iss >> job.jobId >> job.state >> job.pages >> job.dials >> job.tts >> job.sender;
            break;
        case RECV_QUEUE:
            iss >> job.fileName >> job.pages >> job.status >> job.received >> job.sender;
            break;
        // Add other queue types as needed
    }
    
    return job;
}
