/*
 * HylaFAX API Wrapper
 * Provides programmatic access to HylaFAX functionality without command execution
 */
#ifndef _FaxAPI_
#define _FaxAPI_

#include "SendFaxClient.h"
#include "FaxClient.h"
#include "SendFaxJob.h"
#include "FaxDB.h"
#include <vector>
#include <string>

// Forward declarations
struct FaxSubmissionResult;
struct FaxStatusInfo;
struct FaxJobInfo;
struct FaxQueueInfo;

class FaxAPI {
public:
    // Constructor/Destructor
    FaxAPI(const std::string& host = "localhost");
    ~FaxAPI();

    // Connection management
    bool connect(std::string& errorMsg);
    bool disconnect();
    bool isConnected() const;
    bool login(const std::string& username = "", std::string& errorMsg = "");

    // Send fax functionality (equivalent to sendfax)
    struct FaxSendOptions {
        std::string recipient;          // person@number#subaddress
        std::string dialString;         // phone number
        std::string subAddress;         // sub-address
        std::string coverComments;      // cover page comments
        std::string coverRegarding;     // regarding field
        std::string coverFromVoice;     // sender's voice number
        std::string coverFromFax;       // sender's fax number
        std::string coverFromCompany;   // sender's company
        std::string coverFromLocation;  // sender's location
        std::string coverTemplate;     // cover page template
        std::string tagLineFormat;     // tag line format
        std::string jobTag;            // user job identifier
        std::string tsi;               // TSI (Transmitting Station ID)
        std::string sendTime;          // scheduled send time
        std::string killTime;          // job expiration time
        std::string retryTime;         // retry interval
        std::string pageSize;          // page size
        std::string notification;      // notification type
        std::string priority;          // job priority
        float vResolution;             // vertical resolution
        int maxRetries;                // maximum retry attempts
        int maxDials;                  // maximum dial attempts
        bool autoCoverPage;            // generate cover page
        bool useECM;                   // use error correction mode
        bool useXVRes;                 // use extended resolutions
        bool archive;                  // archive completed job
        int desiredSpeed;              // desired transmission speed
        int minSpeed;                  // minimum acceptable speed
        int desiredDataFormat;         // data format (1D, 2D, MMR)
        
        FaxSendOptions();              // constructor with defaults
    };

    FaxSubmissionResult sendFax(const std::vector<std::string>& files, 
                               const std::vector<std::string>& destinations,
                               const FaxSendOptions& options = FaxSendOptions());

    FaxSubmissionResult sendFax(const std::vector<std::string>& files,
                               const std::string& destination,
                               const FaxSendOptions& options = FaxSendOptions());

    // Status checking functionality (equivalent to faxstat)
    enum QueueType {
        SEND_QUEUE,     // -s: jobs in send queue
        DONE_QUEUE,     // -d: jobs in done queue  
        RECV_QUEUE,     // -r: received faxes
        ARCHIVE_QUEUE,  // -a: archived jobs
        DOCUMENT_QUEUE, // -f: queued documents
        SERVER_STATUS   // server/modem status
    };

    struct FaxStatusOptions {
        QueueType queueType;
        bool useGMT;               // use GMT timezone
        bool showServerInfo;       // show server info
        
        FaxStatusOptions(QueueType type = SEND_QUEUE);
    };

    std::vector<FaxJobInfo> getJobStatus(const FaxStatusOptions& options = FaxStatusOptions());
    std::vector<FaxJobInfo> getJobStatus(QueueType queueType);
    FaxJobInfo getJobInfo(const std::string& jobId);
    
    // Job management
    bool killJob(const std::string& jobId, std::string& errorMsg);
    bool suspendJob(const std::string& jobId, std::string& errorMsg);
    bool resumeJob(const std::string& jobId, std::string& errorMsg);
    bool modifyJob(const std::string& jobId, const FaxSendOptions& newOptions, std::string& errorMsg);
    
    // Polling requests
    bool submitPollRequest(const std::string& number, std::string& errorMsg);
    
    // Wait for job completion
    bool waitForJob(const std::string& jobId, std::string& errorMsg);
    
    // Configuration
    void setHost(const std::string& host);
    void setVerbose(bool verbose);
    void setTimeZone(bool useGMT);
    
    // Error handling
    std::string getLastError() const;

private:
    class SendFaxAPIClient;      // Custom SendFaxClient wrapper
    class StatusAPIClient;       // Custom FaxClient wrapper for status
    
    SendFaxAPIClient* sendClient;
    StatusAPIClient* statusClient;
    std::string hostName;
    bool connected;
    bool loggedIn;
    std::string lastError;
    
    // Helper methods
    bool initializeClients();
    void cleanupClients();
    std::string parseDestination(const std::string& dest, std::string& number, std::string& subaddr);
    FaxJobInfo parseJobLine(const std::string& line, QueueType queueType);
};

// Result structures
struct FaxSubmissionResult {
    bool success;
    std::string jobId;
    std::string groupId;
    std::string errorMessage;
    int totalPages;
    
    FaxSubmissionResult() : success(false), totalPages(0) {}
};

struct FaxJobInfo {
    std::string jobId;
    std::string state;
    std::string pages;
    std::string dials;
    std::string tts;        // time to send
    std::string sender;
    std::string number;
    std::string modem;
    std::string tag;
    std::string status;
    
    // For received faxes
    std::string fileName;
    std::string received;   // receive time
    
    FaxJobInfo() {}
};

#endif /* _FaxAPI_ */
