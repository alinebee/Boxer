/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "DDHIDDevice+BXDeviceExtensions.h"

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
	}
    return result;
}
#endif


@implementation DDHidDevice (BXDeviceExtensions)

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
	return [[[deviceClass alloc] initWithHIDDeviceRef: deviceRef error: outError] autorelease];
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
		[self release];
		return nil;
	}
}

- (BOOL) isEqualToDevice: (DDHidDevice *)device
{
	return [self hash] == [device hash];
}

- (NSUInteger) hash
{
	return (NSUInteger)[self locationId] + [self vendorId] + [self productId];
}

- (NSArray *) elementsWithUsage: (DDHidUsage *)usage
{
	NSPredicate *matchingUsage = [NSPredicate predicateWithFormat: @"usage = %@", usage, nil];
	return [[self elements] filteredArrayUsingPredicate: matchingUsage];
}

@end


@implementation DDHidJoystick (BXJoystickExtensions)

- (NSArray *)sticks
{
	return mSticks;
}

- (NSArray *)axisElements
{
	NSMutableArray *axes = [[NSMutableArray alloc] initWithCapacity: 10];
	
	for (DDHidJoystickStick *stick in [self sticks])
		[axes addObjectsFromArray: [stick axisElements]];

	return [axes autorelease];
}

- (NSArray *)povElements
{
	NSMutableArray *povs = [[NSMutableArray alloc] initWithCapacity: 10];
	
	for (DDHidJoystickStick *stick in [self sticks])
		[povs addObjectsFromArray: [stick povElements]];

	return [povs autorelease];
}

- (NSArray *) axisElementsWithUsageID: (unsigned)usageID
{
	NSPredicate *matchingUsageID = [NSPredicate predicateWithFormat: @"usage.usageId = %i", usageID, nil];
	return [[self axisElements] filteredArrayUsingPredicate: matchingUsageID];
}

- (NSArray *) buttonElementsWithUsageID: (unsigned)usageID
{
	NSPredicate *matchingUsageID = [NSPredicate predicateWithFormat: @"usage.usageId = %i", usageID, nil];
	return [[self buttonElements] filteredArrayUsingPredicate: matchingUsageID];
}
@end

@implementation DDHidJoystickStick (BXJoystickStickExtensions)

- (NSArray *)axisElements
{
	NSMutableArray *axes = [mStickElements mutableCopy];
	if (mXAxisElement) [axes addObject: mXAxisElement];
	if (mYAxisElement) [axes addObject: mYAxisElement];
	
	return [axes autorelease];
}

- (NSArray *)povElements
{
	return mPovElements;
}

- (NSArray *) axisElementsWithUsageID: (unsigned)usageID
{
	NSPredicate *matchingUsageID = [NSPredicate predicateWithFormat: @"usage.usageId = %i", usageID, nil];
	return [[self axisElements] filteredArrayUsingPredicate: matchingUsageID];
}

@end


@implementation DDHidUsage (BXUsageEquality)

- (BOOL) isEqualToUsage: (DDHidUsage *)usage
{
	return [self isEqualToUsagePage: [usage usagePage] usageId: [usage usageId]];
}

- (BOOL) isEqual: (id)object
{
	if ([object isKindOfClass: [DDHidUsage class]] && [self isEqualToUsage: object]) return YES;
	else return [super isEqual: object];
}
@end
