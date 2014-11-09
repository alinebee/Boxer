/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXJoystickController.h"
#import "ADBHIDEvent.h"

#import "BXBaseAppController.h"
#import "BXSession.h"
#import "BXDOSWindowController.h"
#import "BXInputController.h"

@interface BXJoystickController ()

@property (retain, nonatomic) ADBHIDMonitor *HIDMonitor;
@property (retain, nonatomic) NSArray *recentHIDRemappers;

@end

@implementation BXJoystickController
@synthesize HIDMonitor = _HIDMonitor;
@synthesize recentHIDRemappers = _recentHIDRemappers;

- (id) init
{
    self = [super init];
    if (self)
    {
        self.HIDMonitor = [[[ADBHIDMonitor alloc] init] autorelease];
        
        self.HIDMonitor.delegate = self;
        NSArray *deviceProfiles = @[[ADBHIDMonitor joystickDescriptor], [ADBHIDMonitor gamepadDescriptor]];
        [self.HIDMonitor observeDevicesMatching: deviceProfiles];
        
        //Clear our cache of running HID remappers whenever Boxer regains the application focus
        //(since the user may have launched/quit other applications while we were inactive).
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(clearRecentHIDRemappers)                                                                     name: NSApplicationDidBecomeActiveNotification
                                                   object: NSApp];
    }
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [self.HIDMonitor stopObserving];
    
    self.recentHIDRemappers = nil;
    self.HIDMonitor = nil;
	
	[super dealloc];
}

+ (NSSet *) keyPathsForValuesAffectingJoystickDevices
{
	return [NSSet setWithObject: @"HIDMonitor.matchedDevices"];
}

- (NSArray *) joystickDevices
{
	return self.HIDMonitor.matchedDevices;
}


#pragma mark -
#pragma mark HID remapper helper methods

+ (NSSet *) HIDRemapperIdentifiers
{
    static NSSet *set;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        set = [[NSSet alloc] initWithObjects:
               @"net.tunah.Enjoy",                          //http://abstractable.net/enjoy/
               @"com.carvware.gpcdaemonlauncher",           //Gamepad Companion's background process
               @"com.orderedbytes.ControllerMateHelper",    //ControllerMate's helper process
               nil];
    });
    
    return set;
}

+ (NSArray *) runningHIDRemapperIdentifiers
{
    NSMutableArray *apps = [NSMutableArray arrayWithCapacity: 2];
    NSSet *identifiers = [self HIDRemapperIdentifiers];
    
    for (NSString *bundleID in identifiers)
    {
        NSArray *appsWithID = [NSRunningApplication runningApplicationsWithBundleIdentifier: bundleID];
        if (appsWithID.count)
            [apps addObject: bundleID];
    }
    
    return apps;
}

- (NSArray *) recentHIDRemappers
{
    //Populate the remapper array the first time we are asked
    if (!_recentHIDRemappers)
    {
        _recentHIDRemappers = [[self.class runningHIDRemapperIdentifiers] retain];
    }
    return [[_recentHIDRemappers retain] autorelease];
}

- (void) clearRecentHIDRemappers
{
    self.recentHIDRemappers = nil;
}


#pragma mark -
#pragma mark BXHIDMonitor delegate methods

- (void) monitor: (ADBHIDMonitor *)monitor didAddHIDDevice: (DDHidJoystick *)device
{
    device.delegate = self;
	[device startListening];
}

- (void) monitor: (ADBHIDMonitor *)monitor didRemoveHIDDevice: (DDHidJoystick *)device
{
    device.delegate = nil;
}


#pragma mark -
#pragma mark ADBHIDDeviceDelegate methods

- (void) dispatchHIDEvent: (ADBHIDEvent *)event
{
	//Forward all HID events to the current window's input controller
    //FIXME: this is gross, instead we should do some kind of subscribe system.
    BXBaseAppController *appController = (BXBaseAppController *)[NSApp delegate];
	BXSession *activeSession = [appController documentForWindow: [NSApp keyWindow]];
	if ([activeSession isKindOfClass: [BXSession class]])
	{
		BXInputController *controller = activeSession.DOSWindowController.inputController;
		[controller dispatchHIDEvent: event];
	}
}

@end
