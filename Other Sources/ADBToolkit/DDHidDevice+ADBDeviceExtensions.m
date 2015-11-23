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


#import "DDHidDevice+ADBDeviceExtensions.h"
#import "DDHidUsage+ADBUsageExtensions.h"

io_service_t createServiceFromHIDDevice(IOHIDDeviceRef deviceRef);

//Use a shortcut function for 10.6
//(We retain the service object to maintain consistency with the 10.5 version)
#ifdef IOHIDDeviceGetService
io_service_t createServiceFromHIDDevice(IOHIDDeviceRef deviceRef)
{
	io_service_t result = IOHIDDeviceGetService(deviceRef);
	
	if (result != MACH_PORT_NULL) IOObjectRetain(result);

	return result;
}
#else
io_service_t createServiceFromHIDDevice(IOHIDDeviceRef deviceRef)
{
	io_service_t result = MACH_PORT_NULL;
	
	//Copypasta from Apple's HID Explorer example code. See that for code comments.
	CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOHIDDeviceKey);
	if (matchingDict)
	{
		CFStringRef locationKey		= CFSTR(kIOHIDLocationIDKey);
		CFTypeRef deviceLocation	= IOHIDDeviceGetProperty(deviceRef, locationKey);
		if (deviceLocation)
		{
			CFDictionaryAddValue(matchingDict, locationKey, deviceLocation);
			
			//This eats a reference to matchingDict, so we don't need a separate release.
			//The result, meanwhile, has a reference count of 1 and must be released by the caller.
			result = IOServiceGetMatchingService(kIOMasterPortDefault, matchingDict);
		}
        else
        {
            CFRelease(matchingDict);
        }
	}
    return result;
}
#endif


@implementation DDHidDevice (ADBDeviceExtensions)

+ (Class) classForHIDDeviceRef: (IOHIDDeviceRef)deviceRef
{
	//IMPLEMENTATION NOTE: we test for conformance rather than just retrieving the usage page and ID
	//and doing a constant comparison, in case the device conforms to multiple usages.
	if (IOHIDDeviceConformsTo(deviceRef, kHIDPage_GenericDesktop, kHIDUsage_GD_Joystick) ||
		IOHIDDeviceConformsTo(deviceRef, kHIDPage_GenericDesktop, kHIDUsage_GD_GamePad))	return [DDHidJoystick class];
	if (IOHIDDeviceConformsTo(deviceRef, kHIDPage_GenericDesktop, kHIDUsage_GD_Mouse))		return [DDHidMouse class];
	if (IOHIDDeviceConformsTo(deviceRef, kHIDPage_GenericDesktop, kHIDUsage_GD_Keyboard))	return [DDHidKeyboard class];
	
	return [DDHidDevice class];
}

+ (id) deviceWithHIDDeviceRef: (IOHIDDeviceRef)deviceRef
						error: (NSError **)outError
{
	Class deviceClass = [self classForHIDDeviceRef: deviceRef];
	return [[deviceClass alloc] initWithHIDDeviceRef: deviceRef error: outError];
}

- (id) initWithHIDDeviceRef: (IOHIDDeviceRef)deviceRef
					  error: (NSError **)outError
{
	io_service_t ioDevice = createServiceFromHIDDevice(deviceRef);
	
	if (ioDevice)
	{
		self = [self initWithDevice: ioDevice error: outError];
		IOObjectRelease(ioDevice);
		return self;
	}
	else
	{
		//TODO: populate outError
		return nil;
	}
}

- (BOOL) isEqualToDevice: (DDHidDevice *)device
{
	return self.hash == device.hash;
}

- (NSUInteger) hash
{
	return self.serialNumber.hash;
}

- (NSArray *) elementsWithUsage: (DDHidUsage *)usage
{
	NSPredicate *matchingUsage = [NSPredicate predicateWithFormat: @"usage = %@", usage, nil];
	return [self.elements filteredArrayUsingPredicate: matchingUsage];
}

- (DDHidElement *) elementWithUsage: (DDHidUsage *)usage
{
    for (DDHidElement *element in self.elements)
    {
        if ([element.usage isEqualToUsage: usage]) return element;
    }
    return nil;
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"%@ %@ (vendor ID 0x%04lx, product ID 0x%04lx)", self.manufacturer, self.productName, self.vendorId, self.productId];
}

@end


@implementation DDHidJoystick (ADBJoystickExtensions)

- (NSArray *) sticks
{
	return mSticks;
}

- (NSArray *) axisElements
{
	NSMutableArray *axes = [[NSMutableArray alloc] initWithCapacity: 10];
	
	for (DDHidJoystickStick *stick in self.sticks)
		[axes addObjectsFromArray: stick.axisElements];

	return axes;
}

- (NSArray *) povElements
{
	NSMutableArray *povs = [[NSMutableArray alloc] initWithCapacity: 10];
	
	for (DDHidJoystickStick *stick in self.sticks)
		[povs addObjectsFromArray: stick.povElements];

	return povs;
}

- (NSArray *) axisElementsWithUsageID: (unsigned)usageID
{
	NSPredicate *matchingUsageID = [NSPredicate predicateWithFormat: @"usage.usageId = %i", usageID, nil];
	return [self.axisElements filteredArrayUsingPredicate: matchingUsageID];
}

- (NSArray *) buttonElementsWithUsageID: (unsigned)usageID
{
	NSPredicate *matchingUsageID = [NSPredicate predicateWithFormat: @"usage.usageId = %i", usageID, nil];
	return [self.buttonElements filteredArrayUsingPredicate: matchingUsageID];
}

- (DDHidElement *) axisElementWithUsageID: (unsigned)usageID
{
    DDHidElement *element;
	for (DDHidJoystickStick *stick in self.sticks)
    {
        element = [stick axisElementWithUsageID: usageID];
        if (element) return element;
    }
    return nil;
}

- (DDHidElement *) buttonElementWithUsageID: (unsigned)usageID
{
	for (DDHidElement *element in self.buttonElements)
    {
        if (element.usage.usageId == usageID) return element;
    }
    return nil;
}

@end

@implementation DDHidJoystickStick (ADBJoystickStickExtensions)

- (NSArray *) axisElements
{
    return mStickElements;
}

- (NSArray *) povElements
{
	return mPovElements;
}

- (NSArray *) axisElementsWithUsageID: (unsigned)usageID
{
	NSPredicate *matchingUsageID = [NSPredicate predicateWithFormat: @"usage.usageId = %i", usageID, nil];
	return [self.axisElements filteredArrayUsingPredicate: matchingUsageID];
}

- (DDHidElement *) axisElementWithUsageID: (unsigned)usageID
{
    for (DDHidElement *element in self.axisElements)
    {
        if (element.usage.usageId == usageID) return element;
    }
    return nil;
}
@end
