/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */


#import "ADBHIDMonitor.h"
#import "DDHidDevice+ADBDeviceExtensions.h"


#pragma mark -
#pragma mark Notification constants

//Posted to the NSWorkspace notification center when an HID device is added or removed.
NSString * const ADBHIDDeviceAdded      = @"ADBHIDDeviceAdded";
NSString * const ADBHIDDeviceRemoved	= @"ADBHIDDeviceRemoved";

//Included in the userInfo dictionary for above notifications.
//Value is a DDHIDDevice subclass corresponding to the device that was added/removed.
NSString * const ADBHIDDeviceKey        = @"ADBHIDDeviceKey";


#pragma mark -
#pragma mark Private method declarations

@interface ADBHIDMonitor ()

- (void) _deviceRefAdded: (IOHIDDeviceRef) ioDeviceRef;
- (void) _deviceRefRemoved: (IOHIDDeviceRef) ioDeviceRef;

@end


#pragma mark -
#pragma mark Implementation

@implementation ADBHIDMonitor
@synthesize delegate = _delegate;


static void _deviceAdded(void *context, IOReturn result, void *sender, IOHIDDeviceRef ioDeviceRef)
{
	if (result == kIOReturnSuccess && ioDeviceRef)
		[(__bridge ADBHIDMonitor *)context _deviceRefAdded: ioDeviceRef];
}

static void _deviceRemoved(void *context, IOReturn result, void *sender, IOHIDDeviceRef ioDeviceRef)
{
	if (result == kIOReturnSuccess && ioDeviceRef)
		[(__bridge ADBHIDMonitor *)context _deviceRefRemoved: ioDeviceRef];
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
    
    CFRelease(_ioManager); _ioManager = NULL;
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
		[self willChangeValueForKey: @"matchedDevices"];
		[_knownDevices removeObjectForKey: key];
		[self didChangeValueForKey: @"matchedDevices"];
		
		[self deviceRemoved: device];
	}
}

- (void) deviceAdded: (DDHidDevice *)device
{
	if ([self.delegate respondsToSelector: @selector(monitor:didAddHIDDevice:)])
	{
		[self.delegate monitor: self didAddHIDDevice: device];
	}
	
	NSNotificationCenter *center = [[NSWorkspace sharedWorkspace] notificationCenter];
	NSDictionary *userInfo = @{ ADBHIDDeviceKey: device };
	[center postNotificationName: ADBHIDDeviceAdded object: self userInfo: userInfo];
}

- (void) deviceRemoved: (DDHidDevice *)device
{
	if ([self.delegate respondsToSelector: @selector(monitor:didRemoveHIDDevice:)])
	{
		[self.delegate monitor: self didRemoveHIDDevice: device];
	}
	
	NSNotificationCenter *center = [[NSWorkspace sharedWorkspace] notificationCenter];
	NSDictionary *userInfo = @{ ADBHIDDeviceKey: device };
	[center postNotificationName: ADBHIDDeviceRemoved object: self userInfo: userInfo];
}

@end
