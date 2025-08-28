/*
 * Example usage of the HylaFAX API
 * Demonstrates sending faxes and checking status without command execution
 */
#include "FaxAPI.h"
#include <iostream>
#include <vector>

int main() {
    // Create API instance
    FaxAPI faxApi("localhost");  // or your HylaFAX server hostname
    
    std::string errorMsg;
    
    // Connect to server
    if (!faxApi.connect(errorMsg)) {
        std::cerr << "Failed to connect: " << errorMsg << std::endl;
        return 1;
    }
    
    // Login (uses current user by default)
    if (!faxApi.login("", errorMsg)) {
        std::cerr << "Failed to login: " << errorMsg << std::endl;
        return 1;
    }
    
    std::cout << "Connected and logged in successfully!" << std::endl;
    
    // Example 1: Send a fax
    std::cout << "\n=== Sending Fax ===" << std::endl;
    
    // Configure fax options
    FaxAPI::FaxSendOptions options;
    options.coverComments = "This is a test fax sent via API";
    options.coverRegarding = "API Testing";
    options.notification = "done";
    options.vResolution = 196.0f;  // high resolution
    options.useECM = true;         // use error correction
    
    // Files to send
    std::vector<std::string> files = {
        "/path/to/document1.pdf",
        "/path/to/document2.ps"
    };
    
    // Destination (can be "John Doe@555-1234#123" format)
    std::string destination = "John Doe@555-1234";
    
    FaxSubmissionResult result = faxApi.sendFax(files, destination, options);
    
    if (result.success) {
        std::cout << "Fax submitted successfully!" << std::endl;
        std::cout << "Job ID: " << result.jobId << std::endl;
        std::cout << "Total pages: " << result.totalPages << std::endl;
    } else {
        std::cout << "Failed to submit fax: " << result.errorMessage << std::endl;
    }
    
    // Example 2: Check fax status
    std::cout << "\n=== Checking Send Queue ===" << std::endl;
    
    std::vector<FaxJobInfo> sendQueue = faxApi.getJobStatus(FaxAPI::SEND_QUEUE);
    
    std::cout << "Jobs in send queue: " << sendQueue.size() << std::endl;
    for (const auto& job : sendQueue) {
        std::cout << "Job " << job.jobId 
                  << " - State: " << job.state
                  << " - Pages: " << job.pages
                  << " - Number: " << job.number << std::endl;
    }
    
    // Example 3: Check completed jobs
    std::cout << "\n=== Checking Done Queue ===" << std::endl;
    
    std::vector<FaxJobInfo> doneQueue = faxApi.getJobStatus(FaxAPI::DONE_QUEUE);
    
    std::cout << "Completed jobs: " << doneQueue.size() << std::endl;
    for (const auto& job : doneQueue) {
        std::cout << "Job " << job.jobId 
                  << " - State: " << job.state
                  << " - Sender: " << job.sender << std::endl;
    }
    
    // Example 4: Check received faxes
    std::cout << "\n=== Checking Received Faxes ===" << std::endl;
    
    std::vector<FaxJobInfo> recvQueue = faxApi.getJobStatus(FaxAPI::RECV_QUEUE);
    
    std::cout << "Received faxes: " << recvQueue.size() << std::endl;
    for (const auto& fax : recvQueue) {
        std::cout << "File: " << fax.fileName
                  << " - Pages: " << fax.pages
                  << " - Received: " << fax.received << std::endl;
    }
    
    // Example 5: Job management (if we have a job ID)
    if (result.success && !result.jobId.empty()) {
        std::cout << "\n=== Job Management Example ===" << std::endl;
        
        // Wait for job completion (this will block)
        std::cout << "Waiting for job " << result.jobId << " to complete..." << std::endl;
        if (faxApi.waitForJob(result.jobId, errorMsg)) {
            std::cout << "Job completed successfully!" << std::endl;
        } else {
            std::cout << "Job wait failed: " << errorMsg << std::endl;
        }
        
        // Alternative: Kill job (uncomment if needed)
        // if (faxApi.killJob(result.jobId, errorMsg)) {
        //     std::cout << "Job killed successfully" << std::endl;
        // } else {
        //     std::cout << "Failed to kill job: " << errorMsg << std::endl;
        // }
    }
    
    // Example 6: Send to multiple destinations
    std::cout << "\n=== Sending to Multiple Destinations ===" << std::endl;
    
    std::vector<std::string> destinations = {
        "John Doe@555-1234",
        "Jane Smith@555-5678#999",
        "Company@555-9999"
    };
    
    FaxSubmissionResult multiResult = faxApi.sendFax(files, destinations, options);
    
    if (multiResult.success) {
        std::cout << "Multi-destination fax submitted: " << multiResult.jobId << std::endl;
    } else {
        std::cout << "Multi-destination fax failed: " << multiResult.errorMessage << std::endl;
    }
    
    // Disconnect
    faxApi.disconnect();
    std::cout << "\nDisconnected from server." << std::endl;
    
    return 0;
}
