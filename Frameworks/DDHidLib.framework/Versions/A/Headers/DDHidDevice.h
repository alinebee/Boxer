/*
 * Copyright (c) 2007 Dave Dribin
 * 
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import <Cocoa/Cocoa.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/hid/IOHIDLib.h>
#include <IOKit/hid/IOHIDKeys.h>

@class DDHidUsage;
@class DDHidElement;
@class DDHidQueue;

@interface DDHidDevice : NSObject
{
    io_object_t mHidDevice;
	IOHIDDeviceInterface122** mDeviceInterface;

    NSMutableDictionary * mProperties;
    DDHidUsage * mPrimaryUsage;
    NSMutableArray * mUsages;
    NSArray * mElements;
    NSMutableDictionary * mElementsByCookie;
    BOOL mListenInExclusiveMode;
    DDHidQueue * mDefaultQueue;
    int mTag;
    int mLogicalDeviceNumber;
}

- (instancetype) initWithDevice: (io_object_t) device error: (NSError **) error;
- (instancetype) initLogicalWithDevice: (io_object_t) device
                   logicalDeviceNumber: (int) logicalDeviceNumber
                                 error: (NSError **) error;
- (NSInteger) logicalDeviceCount;

#pragma mark -
#pragma mark Finding Devices

+ (NSArray<DDHidDevice*> *) allDevices;

+ (NSArray<DDHidDevice*> *) allDevicesMatchingUsagePage: (unsigned) usagePage
                                                usageId: (unsigned) usageId
                                              withClass: (Class) hidClass
                                      skipZeroLocations: (BOOL) emptyLocation;

+ (NSArray<DDHidDevice*> *) allDevicesMatchingCFDictionary: (CFDictionaryRef) matchDictionary
                                                 withClass: (Class) hidClass
                                         skipZeroLocations: (BOOL) emptyLocation;

#pragma mark -
#pragma mark I/O Kit Objects

@property (readonly) io_object_t ioDevice;
- (IOHIDDeviceInterface122**) deviceInterface;

#pragma mark -
#pragma mark Operations

- (void) open;
- (void) openWithOptions: (UInt32) options;
- (void) close;
- (DDHidQueue *) createQueueWithSize: (unsigned) size;
- (long) getElementValue: (DDHidElement *) element;

#pragma mark -
#pragma mark Asynchronous Notification

@property BOOL listenInExclusiveMode;

- (void) startListening;

- (void) stopListening;

@property (readonly, getter=isListening) BOOL listening;

#pragma mark -
#pragma mark Properties

- (NSDictionary *) properties;

- (NSArray *) elements;
- (DDHidElement *) elementForCookie: (IOHIDElementCookie) cookie;

@property (readonly, assign) NSString *productName;
@property (readonly, assign) NSString *manufacturer;
@property (readonly, assign) NSString *serialNumber;
@property (readonly, assign) NSString *transport;
@property (readonly) long vendorId;
@property (readonly) long productId;
@property (readonly) long version;
@property (readonly) long locationId;
@property (readonly) long usagePage;
@property (readonly) long usage;
@property (readonly, retain) DDHidUsage *primaryUsage;
- (NSArray<DDHidUsage*> *) usages;

- (NSComparisonResult) compareByLocationId: (DDHidDevice *) device;

@property int tag;

@end

@interface DDHidDevice (Protected)

- (unsigned) sizeOfDefaultQueue;
- (void) addElementsToDefaultQueue;

@end
