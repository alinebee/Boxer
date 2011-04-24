/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXDeviceExtensions adds some helper methods to DDHidDevice, along with equality comparison.

#import <DDHidLib/DDHidLib.h>
#import <IOKit/hid/IOHIDLib.h>

io_service_t createServiceFromHIDDevice(IOHIDDeviceRef deviceRef);

@interface DDHidDevice (BXDeviceExtensions)

+ (Class) classForHIDDeviceRef: (IOHIDDeviceRef)deviceRef;

+ (id) deviceWithHIDDeviceRef: (IOHIDDeviceRef)deviceRef
						error: (NSError **)outError;

- (id) initWithHIDDeviceRef: (IOHIDDeviceRef)deviceRef error: (NSError **)error;

- (BOOL) isEqualToDevice: (DDHidDevice *)device;

@end
