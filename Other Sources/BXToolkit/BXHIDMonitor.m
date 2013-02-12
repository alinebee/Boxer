/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
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
@synthesize delegate = _delegate;


static void _deviceAdded(void *context, IOReturn result, void *sender, IOHIDDeviceRef ioDeviceRef)
{
	if (result == kIOReturnSuccess && ioDeviceRef)
		[(__bridge BXHIDMonitor *)context _deviceRefAdded: ioDeviceRef];
}

static void _deviceRemoved(void *context, IOReturn result, void *sender, IOHIDDeviceRef ioDeviceRef)
{
	if (result == kIOReturnSuccess && ioDeviceRef)
		[(__bridge BXHIDMonitor *)context _deviceRefRemoved: ioDeviceRef];
}


#pragma mark -
#pragma mark Helper class methods

+ (NSDictionary *) joystickDescriptor
{
	return @{
        (NSString *)CFSTR(kIOHIDDeviceUsagePageKey): @(kHIDPage_GenericDesktop),
        (NSString *)CFSTR(kIOHIDDeviceUsageKey): @(kHIDUsage_GD_Joystick),
    };
}

+ (NSDictionary *) gamepadDescriptor
{
	return @{
        (NSString *)CFSTR(kIOHIDDeviceUsagePageKey): @(kHIDPage_GenericDesktop),
        (NSString *)CFSTR(kIOHIDDeviceUsageKey): @(kHIDUsage_GD_GamePad),
    };
}

+ (NSDictionary *) keyboardDescriptor
{
	return @{
        (NSString *)CFSTR(kIOHIDDeviceUsagePageKey): @(kHIDPage_GenericDesktop),
        (NSString *)CFSTR(kIOHIDDeviceUsageKey): @(kHIDUsage_GD_Keyboard),
    };
}

+ (NSDictionary *) mouseDescriptor
{
	return @{
        (NSString *)CFSTR(kIOHIDDeviceUsagePageKey): @(kHIDPage_GenericDesktop),
        (NSString *)CFSTR(kIOHIDDeviceUsageKey): @(kHIDUsage_GD_Mouse),
    };
}


- (NSArray *) matchedDevices
{
	return [_knownDevices.allValues sortedArrayUsingSelector: @selector(compareByLocationId:)];
}


#pragma mark -
#pragma mark Initialization and deallocation

- (id) init
{
	if ((self = [super init]))
	{
		_ioManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
		_knownDevices = [[NSMutableDictionary alloc] initWithCapacity: 10];
	}
	return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    
	[self stopObserving];
	
    self.delegate = nil;
    
	CFRelease(_ioManager), _ioManager = NULL;
	[_knownDevices release], _knownDevices = nil;
	
	[super dealloc];
}


#pragma mark -
#pragma mark Observing devices

- (void) observeDevicesMatching: (NSArray *)descriptors
{
	[_knownDevices removeAllObjects];
	
	IOHIDManagerSetDeviceMatchingMultiple(_ioManager, (__bridge CFArrayRef)descriptors);
	
	IOHIDManagerRegisterDeviceMatchingCallback(_ioManager, _deviceAdded, (__bridge void *)self);
	IOHIDManagerRegisterDeviceRemovalCallback(_ioManager, _deviceRemoved, (__bridge void *)self);
	
	IOHIDManagerScheduleWithRunLoop(_ioManager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	IOHIDManagerOpen(_ioManager, kIOHIDOptionsTypeNone);
	
}

- (void) stopObserving
{
	[self willChangeValueForKey: @"matchingDevices"];
	[_knownDevices removeAllObjects];
	[self didChangeValueForKey: @"matchingDevices"];
	
	IOHIDManagerUnscheduleFromRunLoop(_ioManager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	IOHIDManagerRegisterDeviceMatchingCallback(_ioManager, NULL, NULL);
	IOHIDManagerRegisterDeviceRemovalCallback(_ioManager, NULL, NULL);
	IOHIDManagerClose(_ioManager, kIOHIDOptionsTypeNone);
}

- (void) _deviceRefAdded: (IOHIDDeviceRef)ioDeviceRef
{
	DDHidDevice *device = [DDHidDevice deviceWithHIDDeviceRef: ioDeviceRef error: NULL];
	if (device)
	{
		NSNumber *key = [NSNumber numberWithUnsignedInteger: (NSUInteger)ioDeviceRef];
		
		[self willChangeValueForKey: @"matchedDevices"];
		[_knownDevices setObject: device forKey: key];
		[self didChangeValueForKey: @"matchedDevices"];
		 
		[self deviceAdded: device];
	}
}
- (void) _deviceRefRemoved: (IOHIDDeviceRef)ioDeviceRef
{
	NSNumber *key = [NSNumber numberWithUnsignedInteger: (NSUInteger)ioDeviceRef];
	DDHidDevice *device = [_knownDevices objectForKey: key];
	if (device)
	{
		[device retain];
		[self willChangeValueForKey: @"matchedDevices"];
		[_knownDevices removeObjectForKey: key];
		[self didChangeValueForKey: @"matchedDevices"];
		
		[self deviceRemoved: device];
		[device release];
	}
}

- (void) deviceAdded: (DDHidDevice *)device
{
	if ([self.delegate respondsToSelector: @selector(monitor:didAddHIDDevice:)])
	{
		[self.delegate monitor: self didAddHIDDevice: device];
	}
	
	NSNotificationCenter *center = [[NSWorkspace sharedWorkspace] notificationCenter];
	NSDictionary *userInfo = @{ BXHIDDeviceKey: device };
	[center postNotificationName: BXHIDDeviceAdded object: self userInfo: userInfo];
}

- (void) deviceRemoved: (DDHidDevice *)device
{
	if ([self.delegate respondsToSelector: @selector(monitor:didRemoveHIDDevice:)])
	{
		[self.delegate monitor: self didRemoveHIDDevice: device];
	}
	
	NSNotificationCenter *center = [[NSWorkspace sharedWorkspace] notificationCenter];
	NSDictionary *userInfo = @{ BXHIDDeviceKey: device };
	[center postNotificationName: BXHIDDeviceRemoved object: self userInfo: userInfo];
}

@end
