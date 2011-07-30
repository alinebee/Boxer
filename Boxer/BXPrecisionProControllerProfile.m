/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//Custom controller profile for the Microsoft Precision Pro flightstick.

#import "BXHIDControllerProfilePrivate.h"


#pragma mark -
#pragma mark Private constants

#define BXPrecisionProControllerVendorID        BXHIDVendorIDMicrosoft
#define BXPrecisionProControllerProductID       0x0008

//These have not been tested to determine if the button layouts match to the Precision Pro.
//Hence this is a guess, based on photos and product-line history.
#define BXForceFeedback2ControllerVendorID      BXHIDVendorIDMicrosoft
#define BXForceFeedback2ControllerProductID     0x001b

#define BXPrecision2ControllerVendorID      BXHIDVendorIDMicrosoft
#define BXPrecision2ControllerProductID     0x0038

#define BXSidewinderControllerVendorID      BXHIDVendorIDMicrosoft
#define BXSidewinderControllerProductID     0x003c


enum {
    BXPrecisionProThrottleAxis = kHIDUsage_GD_Slider
};


@interface BXPrecisionProControllerProfile: BXHIDControllerProfile
@end


@implementation BXPrecisionProControllerProfile

+ (void) load
{
	[BXHIDControllerProfile registerProfile: self];
}

+ (NSArray *) matchedIDs
{
    return [NSArray arrayWithObjects:
            [self matchForVendorID: BXPrecisionProControllerVendorID productID: BXPrecisionProControllerProductID],
            [self matchForVendorID: BXForceFeedback2ControllerVendorID productID: BXForceFeedback2ControllerProductID],
            [self matchForVendorID: BXPrecision2ControllerVendorID productID: BXPrecision2ControllerProductID],
            [self matchForVendorID: BXSidewinderControllerVendorID productID: BXSidewinderControllerProductID],
            nil];
}

//Make the throttle slider behave as an absolute axis when used for throttle,
//rather than relative (the slider does not spring back to center, so relative
//throttle input is inappropriate for it.)
- (id <BXHIDInputBinding>) generatedBindingForAxisElement: (DDHidElement *)element
{
    if ([[element usage] usageId] == BXPrecisionProThrottleAxis && [[self emulatedJoystick] supportsAxis: BXAxisThrottle])
    {
        return [BXAxisToAxis bindingWithAxis: BXAxisThrottle];
    }
    return [super generatedBindingForAxisElement: element];
}

@end