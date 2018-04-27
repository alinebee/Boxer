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


#import <DDHidLib/DDHidLib.h>
#import <IOKit/hid/IOHIDLib.h>

NS_ASSUME_NONNULL_BEGIN

/// ADBDeviceExtensions adds some helper methods for creating DDHidDevices from HIDDeviceRefs,
/// and extends DDHidDevice subclasses to provide a richer introspection API for finding out
/// device capabilities.
@interface DDHidDevice (ADBDeviceExtensions)

+ (Class) classForHIDDeviceRef: (IOHIDDeviceRef)deviceRef;

+ (id) deviceWithHIDDeviceRef: (IOHIDDeviceRef)deviceRef
						error: (NSError **)outError;

- (instancetype) initWithHIDDeviceRef: (IOHIDDeviceRef)deviceRef error: (NSError **)error;

- (BOOL) isEqualToDevice: (DDHidDevice *)device;

/// Returns an array of all elements matching the specified usage.
/// Will be empty if no such elements are present on the device.
- (NSArray<DDHidElement*> *) elementsWithUsage: (DDHidUsage *)usage;

/// Returns the first element matching the specified usage,
/// or nil if no elements were found.
- (nullable DDHidElement *) elementWithUsage: (DDHidUsage *)usage;
@end


@interface DDHidJoystick (ADBJoystickExtensions)

//Arrays of all axis/POV elements/sticks present on this device.
@property (readonly, nonatomic) NSArray<DDHidElement*> *axisElements;
@property (readonly, nonatomic) NSArray<DDHidElement*> *povElements;
@property (readonly, nonatomic) NSArray<DDHidElement*> *sticks;

/// Returns all axis elements conforming to the specified usage ID.
/// Will be empty if no such axis is present on this device.
- (NSArray<DDHidElement*> *) axisElementsWithUsageID: (unsigned)usageID;

/// Returns all button elements corresponding to the specified button usage.
/// Will be empty if no such button is present on this device.
- (NSArray<DDHidElement*> *) buttonElementsWithUsageID: (unsigned)usageID;

/// Convenience method to return the first matching axis element.
/// Returns @c nil if no matching elements were found.
- (nullable DDHidElement *) axisElementWithUsageID: (unsigned)usageID;

/// Convenience method to return the first matching button element.
/// Returns @c nil if no matching elements were found.
- (nullable DDHidElement *) buttonElementWithUsageID: (unsigned)usageID;
@end


@interface DDHidJoystickStick (ADBJoystickStickExtensions)

//Arrays of all axis/POV elements on this stick.
@property (readonly, nonatomic) NSArray<DDHidElement*> *axisElements;
@property (readonly, nonatomic) NSArray<DDHidElement*> *povElements;

/// Returns all axis elements conforming to the specified usage ID.
/// Will be empty if no such axis is present on this stick.
- (NSArray<DDHidElement*> *) axisElementsWithUsageID: (unsigned)usageID;

/// Convenience method to return the first matching axis element.
/// Returns nil if no matching elements were found.
- (nullable DDHidElement *) axisElementWithUsageID: (unsigned)usageID;

@end

NS_ASSUME_NONNULL_END
