/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXHIDMonitor subscribes to HID input messages from DDHIDLib and IOKit and posts notifications
//when devices are added or removed.

#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDLib.h>


#pragma mark -
#pragma mark Notification constants

//Posted to the NSWorkspace notification center when an HID device is added or removed.
extern NSString * const BXHIDDeviceAdded;
extern NSString * const BXHIDDeviceRemoved;

//Included in the userInfo dictionary for above notifications.
//Value is a DDHIDDevice subclass corresponding to the device that was added/removed.
extern NSString * const BXHIDDeviceKey;


@class DDHidDevice;
@protocol BXHIDMonitorDelegate;

@interface BXHIDMonitor: NSObject
{
	IOHIDManagerRef _ioManager;
	NSMutableDictionary *_knownDevices;
	__unsafe_unretained id <BXHIDMonitorDelegate> _delegate;
}

#pragma mark -
#pragma mark Properties

//The devices enumerated by this input manager,
//matching the criteria specified to observeDevicesMatching:
@property (readonly, nonatomic) NSArray *matchedDevices;

//This delegate will receive messages directly whenever devices are added or removed.
@property (assign, nonatomic) id <BXHIDMonitorDelegate> delegate;


#pragma mark -
#pragma mark Helper class methods

//Descriptors to feed to observeDevicesMatching:
+ (NSDictionary *) joystickDescriptor;
+ (NSDictionary *) gamepadDescriptor;
+ (NSDictionary *) mouseDescriptor;
+ (NSDictionary *) keyboardDescriptor;


#pragma mark -
#pragma mark Device observation

//Observe HID devices matching the specified criteria.
//Calling this multiple times will replace the previous criteria
//and repopulate matchedDevices.

//Descriptors should be specified as an array of NSDictionaries,
//according the syntax of IOHIDManagerSetDeviceMatchingMultiple().
//Pass NIL for descriptors to match all HID devices.
- (void) observeDevicesMatching: (NSArray *)descriptors;

//Stop observing HID devices. This will empty matchedDevices.
- (void) stopObserving;

//Called when the specified device is connected, or is already
//connected when observeDevicesMatching: is called.
//Intended to be overridden by subclasses.
- (void) deviceAdded: (DDHidDevice *)device;

//Called when the specified device is removed.
//Intended to be overridden by subclasses.
- (void) deviceRemoved: (DDHidDevice *)device;

@end


@protocol BXHIDMonitorDelegate <NSObject>

@optional
- (void) monitor: (BXHIDMonitor *)monitor didAddHIDDevice: (DDHidDevice *)device;
- (void) monitor: (BXHIDMonitor *)monitor didRemoveHIDDevice: (DDHidDevice *)device;

@end