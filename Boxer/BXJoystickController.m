/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXJoystickController.h"
#import "BXHIDEvent.h"

#import "BXAppController.h"
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
}

- (void) dealloc
{
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
	//Forward all HID events to the currently-active DOS session's input controller
	
	BXSession *session = [[NSApp delegate] currentSession];
	if ([[[session DOSWindowController] window] isKeyWindow])
	{
		BXInputController *controller = [[session DOSWindowController] inputController];
		[controller dispatchHIDEvent: event];
	}
}

@end
