/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//Custom controller profile for the CH Flightstick Pro USB flightstick.
//This corrects the mapping of the throttle axis.

#import "BXHIDControllerProfilePrivate.h"

#pragma mark -
#pragma mark Private constants

#define BXCHFlightstickProUSBVendorID   BXHIDVendorIDCH
#define BXCHFlightstickProUSBProductID  0x00f6

#define BXCHFighterstickUSBVendorID   BXHIDVendorIDCH
#define BXCHFighterstickUSBProductID  0x00f3

#define BXCHCombatStickUSBVendorID   BXHIDVendorIDCH
#define BXCHCombatStickUSBProductID  0x00f4

#define BXCHFlightSimYokeUSBVendorID   BXHIDVendorIDCH
#define BXCHFlightSimYokeUSBProductID  0x00ff

#define BXCHF16CombatStickUSBVendorID   BXHIDVendorIDCH
#define BXCHF16CombatStickUSBProductID  0x0504

enum {
    BXCHFlightstickProUSBThrottleAxis = kHIDUsage_GD_Z,
};

@interface BXCHFlightstickProUSBControllerProfile: BXHIDControllerProfile
@end


@implementation BXCHFlightstickProUSBControllerProfile

+ (void) load
{
	[BXHIDControllerProfile registerProfile: self];
}

+ (NSArray *) matchedIDs
{
    return [NSArray arrayWithObjects:
            [self matchForVendorID: BXCHFlightstickProUSBVendorID productID: BXCHFlightstickProUSBProductID],
            [self matchForVendorID: BXCHFlightstickProUSBVendorID productID: BXCHFighterstickUSBProductID],
            [self matchForVendorID: BXCHFlightstickProUSBVendorID productID: BXCHCombatStickUSBProductID],
            [self matchForVendorID: BXCHFlightstickProUSBVendorID productID: BXCHFlightSimYokeUSBProductID],
            [self matchForVendorID: BXCHFlightstickProUSBVendorID productID: BXCHF16CombatStickUSBProductID],
            nil];
}

- (BXControllerStyle) controllerStyle { return BXControllerStyleFlightstick; }

//Make the throttle slider behave as an absolute axis when used for throttle,
//rather than relative (the slider does not spring back to center, so relative
//throttle input is inappropriate for it.)
- (id <BXHIDInputBinding>) generatedBindingForAxisElement: (DDHidElement *)element
{
    if (element.usage.usageId == BXCHFlightstickProUSBThrottleAxis && [self.emulatedJoystick supportsAxis: BXAxisThrottle])
    {
        return [self bindingFromAxisElement: element toAxis: BXAxisThrottle];
    }
    else
    {
        return [super generatedBindingForAxisElement: element];
    }
}

@end