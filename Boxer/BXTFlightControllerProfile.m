/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXHIDControllerProfilePrivate.h"

enum {
    BXTFlightThrottleAxis = kHIDUsage_GD_Z,
    BXTFlightRudderAxis = kHIDUsage_GD_Rz
};

#pragma mark -
#pragma mark Private constants

#define BXTFlightControllerVendorID        BXHIDVendorIDThrustmaster
#define BXTFlightControllerProductID       0xb108


@interface BXTFlightControllerProfile: BXHIDControllerProfile
@end

@implementation BXTFlightControllerProfile

+ (void) load
{
	[BXHIDControllerProfile registerProfile: self];
}

+ (NSArray *) matchedIDs
{
    return [NSArray arrayWithObjects:
            [self matchForVendorID: BXTFlightControllerVendorID
                         productID: BXTFlightControllerProductID],
            nil];
}

//Correct for flipped throttle and rudder axes, and make the throttle
//act as an absolute axis rather than a relative accumulating one.
- (id <BXHIDInputBinding>) generatedBindingForAxisElement: (DDHidElement *)element
{
    if ([[element usage] usageId] == BXTFlightThrottleAxis &&
        [[self emulatedJoystick] supportsAxis: BXAxisThrottle])
    {
        return [BXAxisToAxis bindingWithAxis: BXAxisThrottle];
    }
    else if ([[element usage] usageId] == BXTFlightRudderAxis &&
             [[self emulatedJoystick] supportsAxis: BXAxisRudder])
    {
        return [BXAxisToAxis bindingWithAxis: BXAxisRudder];
    }
    else
    {
        return [super generatedBindingForAxisElement: element];
    }
}
@end
