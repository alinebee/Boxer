/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXFlightstickAccelerometerLayout.h"
#import "BXEmulatedJoystick.h"


@implementation BXFlightstickAccelerometerLayout

+ (void) load
{
	[BXJoypadLayout registerLayout: self forJoystickType: [BXCHFlightStickPro class]];
	[BXJoypadLayout registerLayout: self forJoystickType: [BXThrustmasterFCS class]];
}

+ (JoypadControllerLayout *)layout
{
    static JoypadControllerLayout *layout = nil;
    if (!layout)
    {
        layout = [[JoypadControllerLayout alloc] init];
        
        [layout setName: @"Boxer: 4-button flightstick with POV switch"];
        
        //We use the accelerometer in lieu of an onscreen analog stick
        [layout addAccelerometer];
        
        //POV hat switch: bottom center of screen
        [layout addDpadWithFrame: CGRectMake(140, 70, 200, 200)
                      identifier: kJoyInputDpad1];
        
        //Primary buttons: blue, rectangular and tall, located along each side of the screen
        [layout addButtonWithFrame: CGRectMake(380,100,100,220) 
                             label: @"1" 
                          fontSize: 36
                             shape: kJoyButtonShapeSquare
                             color: kJoyButtonColorBlue
                        identifier: kJoyInputAButton];
        
        [layout addButtonWithFrame: CGRectMake(0,100,100,220) 
                             label: @"2" 
                          fontSize: 36
                             shape: kJoyButtonShapeSquare
                             color: kJoyButtonColorBlue
                        identifier: kJoyInputBButton];
        
        //Secondary buttons: square, located at the top corners of each side of the screen
        [layout addButtonWithFrame: CGRectMake(380,0,100,100) 
                             label: @"3" 
                          fontSize: 36
                             shape: kJoyButtonShapeSquare
                             color: kJoyButtonColorBlack
                        identifier: kJoyInputXButton];
        
        [layout addButtonWithFrame: CGRectMake(0,0,100,100) 
                             label: @"4" 
                          fontSize: 36
                             shape: kJoyButtonShapeSquare
                             color: kJoyButtonColorBlack
                        identifier: kJoyInputYButton];
        
        //Meta buttons: pill-shaped, located at the top center
        [layout addButtonWithFrame: CGRectMake(120,10,110,30) 
                             label: @"Esc" 
                          fontSize: 16
                             shape: kJoyButtonShapePill
                             color: kJoyButtonColorBlack
                        identifier: kJoyInputStartButton];
        
        [layout addButtonWithFrame: CGRectMake(250,10,110,30) 
                             label: @"Pause" 
                          fontSize: 16
                             shape: kJoyButtonShapePill
                             color: kJoyButtonColorBlack
                        identifier: kJoyInputSelectButton];
    }
    return layout;
}
@end
