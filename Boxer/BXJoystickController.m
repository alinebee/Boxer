/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXJoystickController.h"
#import "BXHIDEvent.h"

#import "BXSession.h"
#import "BXDOSWindowController.h"
#import "BXInputController.h"


@implementation BXJoystickController
@synthesize hidMonitor;

- (void) awakeFromNib
{
	hidMonitor = [[BXHIDMonitor alloc] init];
	
	[hidMonitor setDelegate: self];
	[hidMonitor observeDevicesMatching: [NSArray arrayWithObjects:
										 [BXHIDMonitor joystickDescriptor],
										 [BXHIDMonitor gamepadDescriptor],
										 nil]];

    //Clear our cache of running HID remappers whenever Boxer regains the application focus
    //(since the user may have launched/quit other applications while we were inactive).
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(clearRecentHIDRemappers)                                                                     name: NSApplicationDidBecomeActiveNotification
                                               object: NSApp];
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    
    [recentHIDRemappers release], recentHIDRemappers = nil;
    
	[hidMonitor stopObserving];
	[hidMonitor release], hidMonitor = nil;
	
	[super dealloc];
}

+ (NSSet *) keyPathsForValuesAffectingJoystickDevices
{
	return [NSSet setWithObject: @"hidMonitor.matchedDevices"];
}

- (NSArray *)joystickDevices
{
	return [hidMonitor matchedDevices];
}


#pragma mark -
#pragma mark HID remapper helper methods

+ (NSSet *) HIDRemapperIdentifiers
{
    static NSSet *set = nil;
    if (!set) set = [[NSSet alloc] initWithObjects:
                     @"com.carvware.gpcdaemonlauncher",         //Gamepad Companion's background process
                     @"com.orderedbytes.ControllerMateHelper",  //ControllerMate's helper process
                     nil];
    
    return set;
}

+ (NSArray *) runningHIDRemapperIdentifiers
{
    NSMutableArray *apps = [NSMutableArray arrayWithCapacity: 2];
    NSSet *identifiers = [self HIDRemapperIdentifiers];
    
    //10.6+
    if ([[NSWorkspace sharedWorkspace] respondsToSelector: @selector(runningApplications)])
    {
        for (NSString *bundleID in identifiers)
        {
            NSArray *appsWithID = [NSRunningApplication runningApplicationsWithBundleIdentifier: bundleID];
            if ([appsWithID count]) [apps addObject: bundleID];
        }
    }
    //10.5
    else
    {
        NSArray *runningApps = [[NSWorkspace sharedWorkspace] launchedApplications];
        for (NSDictionary *appDetails in runningApps)
        {
            NSString *bundleID = [appDetails objectForKey: @"NSApplicationBundleIdentifier"];
            if ([identifiers containsObject: bundleID])
            {
                [apps addObject: bundleID];
            }
        }
    }
    
    return apps;
}

- (NSArray *) recentHIDRemappers
{
    //Populate the remapper array the first time we are asked
    if (!recentHIDRemappers)
    {
        recentHIDRemappers = [[[self class] runningHIDRemapperIdentifiers] retain];
    }
    return recentHIDRemappers;
}

- (void) clearRecentHIDRemappers
{
    [recentHIDRemappers release];
    recentHIDRemappers = nil;
}


#pragma mark -
#pragma mark BXHIDMonitor delegate methods

- (void) monitor: (BXHIDMonitor *)monitor didAddHIDDevice: (DDHidDevice *)device
{
	[(DDHidJoystick *)device setDelegate: self];
	[device startListening];
}

- (void) monitor: (BXHIDMonitor *)monitor didRemoveHIDDevice: (DDHidDevice *)device
{
	[(DDHidJoystick *)device setDelegate: nil];
}


#pragma mark -
#pragma mark BXHIDDeviceDelegate methods

- (void) dispatchHIDEvent: (BXHIDEvent *)event
{
	//Forward all HID events to the current window's input controller
	id activeDocument = [[[NSApp keyWindow] windowController] document];
	if ([activeDocument isKindOfClass: [BXSession class]])
	{
		BXInputController *controller = [[activeDocument DOSWindowController] inputController];
		[controller dispatchHIDEvent: event];
	}
}

@end
