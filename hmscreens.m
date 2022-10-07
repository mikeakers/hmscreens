//
// Created 22 July 2010 by Hank McShane
// version 0.1
// requires Mac OS X 10.4 or higher
//
// Use hmscreens to either get information about your screens
// or for setting the main screen (the screen with the menu bar).
//
// Usage: hmscreens
// [-h] shows the help text
// [-info [<Screen ID>]] Screen ID to show information about / without ID to show info for all connected screens
// [-modes <Screen ID>] Screen ID to show all supported resolution modes
// [-screenIDs] returns only the screen IDs for the connected screens
// [-setMainID <Screen ID>] Screen ID of the screen that you want to make the main screen
// [-othersStartingPosition <position>] left, right, top, or bottom... with -setMainID, this determines placement of other screens
// [-activate <Screen ID>] Screen ID of an active screen that you want make inactive
// [-deactivate <Screen ID>] Screen ID of an inactive screen that you want to make active
//
// Examples:
// hmscreens -info
// returns information about your attached screens including the Screen ID
//
// hmscreens -setMainID 69670848 -othersStartingPosition left
// makes the screen with the Screen ID 69670848 the main screen.
// Also positions other screens to the left of the main screen as shown
// under the "Arrangement" section of the Displays preference pane.
//
// NOTE: Global Position {0, 0} coordinate (as shown under -info)
// is the lower left corner of the main screen
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>

void printHelp();
void displaysInfo(NSString* optionalScreenID);
void displayModes(NSString* screenID);
void screenIDs();
void setMainScreen(NSString* screenID, NSString* othersStartingPosition);
void swapDisplays();
void setScreenActive(NSString* screenID, BOOL enable);

// undocumented CoreGraphics function
extern CGError CGSConfigureDisplayEnabled(CGDisplayConfigRef, CGDirectDisplayID, bool);

#define MAX_DISPLAYS 32

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    // get command line arguments
    NSArray* pInfo = [[NSArray alloc] initWithArray:[[NSProcessInfo processInfo] arguments]];
    
    if ([pInfo count] == 1) {
        printHelp();
        displayModes(nil);
    } else if ([[pInfo objectAtIndex:1] isEqualToString:@"-h"]) {
        printHelp();
    } else if ([[pInfo objectAtIndex:1] isEqualToString:@"-info"]) {
        NSString* screenID = [[NSUserDefaults standardUserDefaults] stringForKey:@"info"];
        if (screenID && [screenID intValue] == 0) {
            printHelp();
        } else if (screenID) {
            displaysInfo(screenID);
        } else {
            displaysInfo(nil);
        }
    } else if ([[pInfo objectAtIndex:1] isEqualToString:@"-modes"]) {
        NSString* screenID = [[NSUserDefaults standardUserDefaults] stringForKey:@"modes"];
        if (!screenID || [screenID intValue] == 0) {
            printHelp();
        } else {
            displaysInfo(screenID);
            displayModes(screenID);
        }
    } else if ([[pInfo objectAtIndex:1] isEqualToString:@"-screenIDs"]) {
        screenIDs();
    } else if ([[pInfo objectAtIndex:1] isEqualToString:@"-setMainID"]) {
        NSString* screenID = [[NSUserDefaults standardUserDefaults] stringForKey:@"setMainID"];
        NSString* othersStartingPosition = [[NSUserDefaults standardUserDefaults] stringForKey:@"othersStartingPosition"];
        if (!screenID || [screenID intValue] == 0 || !othersStartingPosition || [othersStartingPosition length] == 0) {
            printHelp();
        } else {
            setMainScreen(screenID, othersStartingPosition);
        }
    } else if ([[pInfo objectAtIndex:1] isEqualToString:@"-swapDisplays"]) {
        swapDisplays();
    } else if ([[pInfo objectAtIndex:1] isEqualToString:@"-deactivate"]) {
        NSString* screenID = [[NSUserDefaults standardUserDefaults] stringForKey:@"deactivate"];
        if (!screenID || [screenID intValue] == 0) {
            printHelp();
        } else {
            setScreenActive(screenID, false);
        }
    } else if ([[pInfo objectAtIndex:1] isEqualToString:@"-activate"]) {
        NSString* screenID = [[NSUserDefaults standardUserDefaults] stringForKey:@"activate"];
        if (!screenID || [screenID intValue] == 0) {
            printHelp();
        } else {
            setScreenActive(screenID, true);
        }
    } else {
        printHelp();
    }
    [pInfo release];
    
    [pool drain];
    return 0;
}

//----------------------------------------
//            FUNCTIONS
//----------------------------------------
#pragma mark -
#pragma mark FUNCTIONS

void screenIDs() {
    CGDirectDisplayID activeDisplays[MAX_DISPLAYS];
    CGDisplayErr err;
    CGDisplayCount displayCount;
    
    // get the active displays
    err = CGGetActiveDisplayList(MAX_DISPLAYS, activeDisplays, &displayCount);
    if ( err != kCGErrorSuccess ) {
        printf("Error: cannot get displays:\n%d\n", err);
        return;
    }
    
    int i;
    for (i=0; i<displayCount; i++) {
        printf("%i\n", activeDisplays[i]);
    }
}

void setMainScreen(NSString* screenID, NSString* othersStartingPosition) {
    CGDirectDisplayID activeDisplays[MAX_DISPLAYS];
    CGDisplayErr err;
    CGDisplayCount displayCount;
    CGDisplayConfigRef config;
    
    // get the active displays
    err = CGGetActiveDisplayList(MAX_DISPLAYS, activeDisplays, &displayCount);
    if ( err != kCGErrorSuccess ) {
        printf("Error: cannot get displays:\n%d\n", err);
        return;
    }
    
    // error if more than 5 displays
    // we only handle 5 because we set the main and left/right/top/bottom positions
    if (displayCount > 5) {
        printf("Error: hmscreens can only handle a max of 5 screens when adjusting the main screen\n");
        return;
    }
    
    // validate that the screenID exists and get the index number of it
    int i, newMainScreenIndex;
    BOOL foundScreenID = NO;
    for (i=0; i<displayCount; i++) {
        CGDirectDisplayID thisDisplayID = activeDisplays[i];
        NSString* thisDisplayIDString = [NSString stringWithFormat:@"%i", thisDisplayID];
        if ([thisDisplayIDString isEqualToString:screenID]) {
            foundScreenID = YES;
            break;
        }
    }
    
    if (foundScreenID) {
        newMainScreenIndex = i;
    } else {
        printf("Error: Screen ID %s could not be found\n", [screenID UTF8String]);
        return;
    }

    // construct othersPos array which determines how we position the other displays
    NSArray* othersPos;
    if ([othersStartingPosition isEqualToString:@"left"]) {
        othersPos = [NSArray arrayWithObjects:@"left", @"right", @"top", @"bottom", nil];
    } else if ([othersStartingPosition isEqualToString:@"right"]) {
        othersPos = [NSArray arrayWithObjects:@"right", @"left", @"top", @"bottom", nil];
    } else if ([othersStartingPosition isEqualToString:@"top"]) {
        othersPos = [NSArray arrayWithObjects:@"top", @"bottom", @"left", @"right", nil];
    } else if ([othersStartingPosition isEqualToString:@"bottom"]) {
        othersPos = [NSArray arrayWithObjects:@"bottom", @"top", @"left", @"right", nil];
    } else {
        othersPos = [NSArray arrayWithObjects:@"left", @"right", @"top", @"bottom", nil];
    }
    
    // configure the displays
    int othersCount = 0;
    CGBeginDisplayConfiguration(&config);
    for(i=0; i<displayCount; i++) {
        if (i == newMainScreenIndex) { // make this one the main screen
            CGConfigureDisplayOrigin(config, activeDisplays[i], 0, 0); //Set the as the new main display by positioning at 0,0
        } else {
            NSString* thisPos = [othersPos objectAtIndex:othersCount];
            
            if ([thisPos isEqualToString:@"left"]) {
                CGConfigureDisplayOrigin(config, activeDisplays[i], -1*((int32_t)CGDisplayPixelsWide(activeDisplays[i])), 0);
            } else if ([thisPos isEqualToString:@"right"]) {
                CGConfigureDisplayOrigin(config, activeDisplays[i], (int32_t)CGDisplayPixelsWide(activeDisplays[newMainScreenIndex]), 0);
            } else if ([thisPos isEqualToString:@"top"]) {
                CGConfigureDisplayOrigin(config, activeDisplays[i], 0, -1*((int32_t)CGDisplayPixelsHigh(activeDisplays[i])));
            } else if ([thisPos isEqualToString:@"bottom"]) {
                CGConfigureDisplayOrigin(config, activeDisplays[i], 0, (int32_t)CGDisplayPixelsHigh(activeDisplays[newMainScreenIndex]));
            }
            othersCount++;
        }
    }
    CGCompleteDisplayConfiguration(config, kCGConfigureForSession);
}

void setScreenActive(NSString* screenID, BOOL active) {
    if (!screenID) {
        exit(1);
    }
    CGDirectDisplayID cgScreenID = (CGDirectDisplayID)[screenID intValue];
    CGDisplayConfigRef config;
    CGBeginDisplayConfiguration(&config);
    
    CGError err = CGSConfigureDisplayEnabled(config, cgScreenID, active);
    
    if (err != kCGErrorSuccess)
    {
        printf("Error: Unable to %s screen ID %s, error %d\n", active?"activate":"deactivate", [screenID UTF8String], err);
        CGCancelDisplayConfiguration(config);
        exit(1);
    }
    else
    {
        CGCompleteDisplayConfiguration(config, kCGConfigureForSession);
    }
    
    printf("After %sactivation:\n\n", active ? "" : "de");
    
    displaysInfo(screenID);
}

void printHelp() {
    NSString* a = @"Use hmscreens to either get information about your screens";
    NSString* b = @"or for setting the main screen (the screen with the menu bar).";
    
    NSString* c = @"Usage: hmscreens";
    NSString* d = @"[-h] shows the help text";
    NSString* e = @"[-info [<Screen ID>]] Screen ID to show information about /";
    NSString* f = @"                      without ID to show info for all connected screens";
    NSString* g = @"[-modes <Screen ID>] Screen ID to show all supported resolution modes";
    NSString* h = @"[-screenIDs] returns only the screen IDs for the connected screens";
    NSString* i = @"[-setMainID <Screen ID>] Screen ID of the screen that you want to make the main screen";
    NSString* j = @"[-othersStartingPosition <position>] left, right, top, or bottom";
    NSString* k = @"\t\tuse this with -setMainID to determine placement of other screens";
    NSString* l = @"[-activate <Screen ID>] Screen ID of an active screen that you want make inactive";
    NSString* m = @"[-deactivate <Screen ID>] Screen ID of an inactive screen that you want to make active";

    NSString* o = @"Examples:";
    NSString* p = @"hmscreens -info";
    NSString* q = @"\treturns information about your attached screens including the Screen ID";
    
    NSString* r = @"hmscreens -setMainID 69670848 -othersStartingPosition left";
    NSString* s = @"\tmakes the screen with the Screen ID 69670848 the main screen.";
    NSString* t = @"\tAlso positions other screens to the left of the main screen as shown";
    NSString* u = @"\tunder the \"Arrangement\" section of the Displays preference pane.";
    
    NSString* v = @"NOTE: Global Position {0, 0} coordinate (as shown under -info)";
    NSString* w = @"\tis the lower left corner of the main screen";
    
    NSString* z = [NSString stringWithFormat:@"%@\n%@\n\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n\n%@\n%@\n%@\n\n%@\n%@\n%@\n%@\n\n%@\n%@\n",a,b,c,d,e,f,g,h,i,j,k,l,m,o,p,q,r,s,t,u,v,w];
    printf("%s\n", [z UTF8String]);
}

void displaysInfo(NSString* optionalScreenID) {
    NSArray* allScreens = [NSScreen screens];
    NSMutableSet* onlineScreenIDs = [[NSMutableSet alloc] init];
    CGDirectDisplayID cgFindScreenID = (CGDirectDisplayID)[optionalScreenID intValue];
    
    int i;
    for (i=0; i<[allScreens count]; i++) {
        NSScreen* thisScreen = [allScreens objectAtIndex:i];
        NSDictionary* deviceDescription = [thisScreen deviceDescription];
        //NSLog(@"deviceDescription: %@", deviceDescription);
        
        // screen id
        NSNumber* screenID = [deviceDescription valueForKey:@"NSScreenNumber"];
        CGDirectDisplayID cgScreenID = (CGDirectDisplayID)[screenID intValue];
        if (optionalScreenID && cgScreenID != cgFindScreenID) {
            continue;
        }
        printf("Screen ID: %i\n", cgScreenID);
        
        [onlineScreenIDs addObject: screenID];
        
        // vendor product serial values
        printf("Vendor / Product / Serial #: %x %x %x\n", CGDisplayVendorNumber(cgScreenID), CGDisplayModelNumber(cgScreenID), CGDisplaySerialNumber(cgScreenID));
        
        // size
        NSSize size = [[deviceDescription objectForKey:NSDeviceSize] sizeValue];
        printf("Size: %s\n", [NSStringFromSize(size) UTF8String]);
        
        // global position
        NSRect frame = [thisScreen frame];
        int x1 = frame.origin.x;
        int y1 = frame.origin.y;
        int x2 = x1 + frame.size.width;
        int y2 = y1 + frame.size.height;
        printf("Global Position: {{%i, %i}, {%i, %i}}\n", x1, y1, x2, y2);
        
        // color space
        NSString* colorSpace = [deviceDescription valueForKey:NSDeviceColorSpaceName];
        printf("Color Space: %s\n", [colorSpace UTF8String]);
        
        // depth ie. 32 & 24 are millions of colors, 16 is thousands, 8 is 256
        NSWindowDepth depth = [thisScreen depth];
        int bpp = (int)NSBitsPerPixelFromDepth(depth);
        printf("BitsPerPixel: %d\n", bpp);

        // bpp might not report >24 when HDR. this is from SO, quite possible it's wrong
        Boolean wideGamut = [thisScreen canRepresentDisplayGamut:NSDisplayGamutP3];
        if (wideGamut) {
            printf("HDR: YES\n");
        } else {
            printf("HDR: NO\n");
        }
        
        // resolution
        NSSize resolution = [[deviceDescription objectForKey:NSDeviceResolution] sizeValue];
        printf("Resolution(dpi): %s\n", [NSStringFromSize(resolution) UTF8String]);
        
        // refresh rate
        double refresh;
        CGDisplayModeRef mode = CGDisplayCopyDisplayMode(cgScreenID);
        refresh = CGDisplayModeGetRefreshRate(mode);
        CGDisplayModeRelease(mode);
        if (refresh != 0.0) {
            printf("Refresh Rate: %.1f\n", refresh);
        } else {
            CVDisplayLinkRef displayLink;
            if (CVDisplayLinkCreateWithCGDisplay(cgScreenID, &displayLink) == kCVReturnSuccess)
            {
                CVTime cvtime = CVDisplayLinkGetNominalOutputVideoRefreshPeriod(displayLink);
                // Guard against cvtime being kCVZeroTime or kCVIndefiniteTime
                if (cvtime.flags == 0 && cvtime.timeValue > 0)
                {
                    double refreshRate = ceil(cvtime.timeScale) / cvtime.timeValue;
                    printf("Panel Refresh Rate: %.2fHz\n\n", refreshRate);
                }
                
                CFRelease(displayLink);
            }
        }
        
        // usesQuartzExtreme
        BOOL usesQuartzExtreme = CGDisplayUsesOpenGLAcceleration(cgScreenID);
        if (usesQuartzExtreme) {
            printf("Uses Quartz Extreme: YES\n");
        } else {
            printf("Uses Quartz Extreme: NO\n");
        }
        
        printf("\n");
        
        if (optionalScreenID) {
            return;
        }
    }
    
    const int hugeDisplaysCount = 32;
    uint32_t allDisplaysCount = 0;
    CGDirectDisplayID allDisplays[hugeDisplaysCount];
    if (CGGetOnlineDisplayList(hugeDisplaysCount, allDisplays, &allDisplaysCount) == kCGErrorSuccess) {
        for (int i = 0; i < allDisplaysCount; ++i) {
            CGDirectDisplayID cgScreenID = allDisplays[i];
            if (optionalScreenID && cgScreenID != cgFindScreenID) {
                continue;
            }
            
            if ([onlineScreenIDs containsObject: @(cgScreenID)]) {
                continue;
            }
            
            if (!CGDisplayIsActive(cgScreenID)) {
                printf("Disabled screen ID: %d\n", cgScreenID);
            } else if (CGDisplayIsInMirrorSet(cgScreenID)) {
                printf("Mirrored screen ID: %d\n", cgScreenID);
            } else {
                printf("Additional omitted screen ID: %d\n", cgScreenID);
            }
            
            // size
            CGDisplayModeRef mode = CGDisplayCopyDisplayMode(cgScreenID);
            NSSize size = NSMakeSize(CGDisplayModeGetPixelWidth(mode), CGDisplayModeGetPixelHeight(mode));
            printf("Size: %s\n", [NSStringFromSize(size) UTF8String]);
            
            printf("\n");
            
            if (optionalScreenID) {
                return;
            }
        }
    }
    
    if (optionalScreenID) {
        printf("Screen with ID %d not found\n", cgFindScreenID);
        exit(1);
    }
}

void displayModes(NSString* screenID) {
    if (!screenID) {
        exit(1);
    }
    CGDirectDisplayID cgScreenID = (CGDirectDisplayID)[screenID intValue];
    CFArrayRef modes = CGDisplayCopyAllDisplayModes(cgScreenID, nil);
    CFIndex n = CFArrayGetCount(modes);
    
    printf("%d Resolution Modes for Screen ID %d:\n", (int)n, cgScreenID);
    
    for (CFIndex i = 0; i < n; i++) {
        CGDisplayModeRef mode = (CGDisplayModeRef)CFArrayGetValueAtIndex(modes, i);
        
        uint32_t width = (uint32_t)CGDisplayModeGetPixelWidth(mode);
        uint32_t height = (uint32_t)CGDisplayModeGetPixelHeight(mode);
        
        uint32_t pointsWidth = (uint32_t)CGDisplayModeGetWidth(mode);  // !!! not reliably in points coordinates :(
        double scaleFactor = 1.0;
        // sanity check to assure division below won't crash, don't expect value to ever really be zero
        if (width) {
            scaleFactor = (double)width / (double)pointsWidth;
        }
        
        char *nativeStr = (CGDisplayModeGetIOFlags(mode) & kDisplayModeNativeFlag) ? "(Native)" : "";
        
        // This returns 0 on some non CRT monitors
        double refreshRate = CGDisplayModeGetRefreshRate(mode);
        if (refreshRate == 0.0) {
            printf("%2d. %ux%u %0.0fx %s\n", (int)i, width, height, scaleFactor, nativeStr);
        } else {
            printf("%2d. %ux%u %0.0fx @%.1fHz %s\n", (int)i, width, height, scaleFactor, refreshRate, nativeStr);
        }
    }
    
    CFRelease(modes);
    
    printf("\n");
}

void swapDisplays() {
    NSArray* allScreens = [NSScreen screens];

    if (allScreens.count != 2) {
        printf("ERROR: swapDisplays only supports 2 screens\n");
        exit(1);
    }

    for (int i = 0; i < [allScreens count]; i++) {
        NSScreen* thisScreen = [allScreens objectAtIndex:i];
        NSDictionary* deviceDescription = [thisScreen deviceDescription];
        //NSLog(@"deviceDescription: %@", deviceDescription);

        // screen id
        NSNumber* screenID = [deviceDescription valueForKey:@"NSScreenNumber"];

        // global position
        NSRect frame = [thisScreen frame];
        int x1 = frame.origin.x;
        int y1 = frame.origin.y;

        if (x1 == 0 && y1 == 0) {
            printf("%d is the main display\n", screenID.intValue);
        } else {
            printf("%d is the second display\n", screenID.intValue);
            printf("making %d the main display\n", screenID.intValue);
            setMainScreen(screenID.stringValue, @"left");
        }
    }
}
