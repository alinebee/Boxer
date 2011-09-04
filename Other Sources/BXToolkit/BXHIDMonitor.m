/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXHIDMonitor.h"
#import "DDHidDevice+BXDeviceExtensions.h"


#pragma mark -
#pragma mark Notification constants

//Posted to the NSWorkspace notification center when an HID device is added or removed.
NSString * const BXHIDDeviceAdded	= @"BXHIDDeviceAdded";
NSString * const BXHIDDeviceRemoved	= @"BXHIDDeviceRemoved";

//Included in the userInfo dictionary for above notifications.
//Value is a DDHIDDevice subclass corresponding to the device that was added/removed.
NSString * const BXHIDDeviceKey = @"BXHIDDeviceKey";


#pragma mark -
#pragma mark Private method declarations

@interface BXHIDMonitor ()
- (void) _deviceRefAdded: (IOHIDDeviceRef) ioDeviceRef;
- (void) _deviceRefRemoved: (IOHIDDeviceRef) ioDeviceRef;
@end


#pragma mark -
#pragma mark Implementation

@implementation BXHIDMonitor
@synthesize delegate;


static void _deviceAdded(void *context, IOReturn result, void *sender, IOHIDDeviceRef ioDeviceRef)
{
	if (result == kIOReturnSuccess && ioDeviceRef)
		[(BXHIDMonitor *)context _deviceRefAdded: ioDeviceRef];
}

static void _deviceRemoved(void *context, IOReturn result, void *sender, IOHIDDeviceRef ioDeviceRef)
{
	if (result == kIOReturnSuccess && ioDeviceRef)
		[(BXHIDMonitor *)context _deviceRefRemoved: ioDeviceRef];
}


#pragma mark -
#pragma mark Helper class methods

+ (NSDictionary *) joystickDescriptor
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInteger: kHIDPage_GenericDesktop],	(NSString *)CFSTR(kIOHIDDeviceUsagePageKey),
			[NSNumber numberWithInteger: kHIDUsage_GD_Joystick],	(NSString *)CFSTR(kIOHIDDeviceUsageKey),
			nil];
}

+ (NSDictionary *) gamepadDescriptor
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInteger: kHIDPage_GenericDesktop],	(NSString *)CFSTR(kIOHIDDeviceUsagePageKey),
			[NSNumber numberWithInteger: kHIDUsage_GD_GamePad],		(NSString *)CFSTR(kIOHIDDeviceUsageKey),
			nil];
}

+ (NSDictionary *) keyboardDescriptor
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInteger: kHIDPage_GenericDesktop],	(NSString *)CFSTR(kIOHIDDeviceUsagePageKey),
			[NSNumber numberWithInteger: kHIDUsage_GD_Keyboard],	(NSString *)CFSTR(kIOHIDDeviceUsageKey),
			nil];
}

+ (NSDictionary *) mouseDescriptor
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInteger: kHIDPage_GenericDesktop],	(NSString *)CFSTR(kIOHIDDeviceUsagePageKey),
			[NSNumber numberWithInteger: kHIDUsage_GD_Mouse],		(NSString *)CFSTR(kIOHIDDeviceUsageKey),
			nil];
}


- (NSArray *) matchedDevices
{
	return [[knownDevices allValues] sortedArrayUsingSelector: @selector(compareByLocationId:)];
}


#pragma mark -
#pragma mark Initialization and deallocation

- (id) init
{
	if ((self = [super init]))
	{
		ioManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
		knownDevices = [[NSMutableDictionary alloc] initWithCapacity: 10];
	}
	return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    
	[self stopObserving];
	
	[self setDelegate: nil];
	
	CFRelease(ioManager), ioManager = nil;
	
	[knownDevices release], knownDevices = nil;
	
	[super dealloc];
}


#pragma mark -
#pragma mark Observing devices

- (void) observeDevicesMatching: (NSArray *)descriptors
{
	[knownDevices removeAllObjects];
	
	IOHIDManagerSetDeviceMatchingMultiple(ioManager, (CFArrayRef)descriptors);
	
	IOHIDManagerRegisterDeviceMatchingCallback(ioManager, _deviceAdded, self);
	IOHIDManagerRegisterDeviceRemovalCallback(ioManager, _deviceRemoved, self);
	
	IOHIDManagerScheduleWithRunLoop(ioManager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	IOHIDManagerOpen(ioManager, kIOHIDOptionsTypeNone);
	
}

- (void) stopObserving
{
	[self willChangeValueForKey: @"matchingDevices"];
	[knownDevices removeAllObjects];
	[self didChangeValueForKey: @"matchingDevices"];
	
	IOHIDManagerUnscheduleFromRunLoop(ioManager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	IOHIDManagerRegisterDeviceMatchingCallback(ioManager, NULL, NULL);
	IOHIDManagerRegisterDeviceRemovalCallback(ioManager, NULL, NULL);
	IOHIDManagerClose(ioManager, kIOHIDOptionsTypeNone);
}

- (void) _deviceRefAdded: (IOHIDDeviceRef)ioDeviceRef
{
	DDHidDevice *device = [DDHidDevice deviceWithHIDDeviceRef: ioDeviceRef error: NULL];
	if (device)
	{
		NSNumber *key = [NSNumber numberWithUnsignedInteger: (NSUInteger)ioDeviceRef];
		
		[self willChangeValueForKey: @"matchedDevices"];
		[knownDevices setObject: device forKey: key];
		[self didChangeValueForKey: @"matchedDevices"];
		 
		[self deviceAdded: device];
	}
}
- (void) _deviceRefRemoved: (IOHIDDeviceRef)ioDeviceRef
{
	NSNumber *key = [NSNumber numberWithUnsignedInteger: (NSUInteger)ioDeviceRef];
	DDHidDevice *device = [knownDevices objectForKey: key];
	if (device)
	{
		[device retain];
		[self willChangeValueForKey: @"matchedDevices"];
		[knownDevices removeObjectForKey: key];
		[self didChangeValueForKey: @"matchedDevices"];
		
		[self deviceRemoved: device];
		[device release];
	}
}

- (void) deviceAdded: (DDHidDevice *)device
{
	if ([delegate respondsToSelector: @selector(monitor:didAddHIDDevice:)])
	{
		[delegate monitor: self didAddHIDDevice: device];
	}
	
	NSNotificationCenter *center = [[NSWorkspace sharedWorkspace] notificationCenter];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject: device forKey: BXHIDDeviceKey];
	[center postNotificationName: BXHIDDeviceAdded object: self userInfo: userInfo];
}

- (void) deviceRemoved: (DDHidDevice *)device
{
	if ([delegate respondsToSelector: @selector(monitor:didRemoveHIDDevice:)])
	{
		[delegate monitor: self didRemoveHIDDevice: device];
	}
	
	NSNotificationCenter *center = [[NSWorkspace sharedWorkspace] notificationCenter];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject: device forKey: BXHIDDeviceKey];
	[center postNotificationName: BXHIDDeviceRemoved object: self userInfo: userInfo];
}

@end
