/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXJoystickController.h"
#import "BXHIDEvent.h"

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
	NSLog(@"Device added: %@");
	[(DDHidJoystick *)device setDelegate: self];
	[device startListening];
}

- (void) monitor: (BXHIDMonitor *)monitor didRemoveHIDDevice: (DDHidDevice *)device
{
	NSLog(@"Device removed: %@");
	[(DDHidJoystick *)device setDelegate: nil];
}


#pragma mark -
#pragma mark BXHIDDeviceDelegate methods

- (void) HIDJoystickButtonDown: (BXHIDEvent *)event
{
	NSLog(@"%@", event);
}

- (void) HIDJoystickButtonUp: (BXHIDEvent *)event
{
	NSLog(@"%@", event);
}

- (void) HIDJoystickAxisChanged: (BXHIDEvent *)event
{
	NSLog(@"%@", event);
}

@end
