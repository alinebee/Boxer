/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BX4ButtonWheelLayout.h"
#import "BXEmulatedJoystick.h"


@implementation BX4ButtonWheelLayout

+ (void) load
{
	[BXJoypadLayout registerLayout: self forJoystickType: [BX3AxisWheel class]];
}

+ (JoypadControllerLayout *)layout
{
    static JoypadControllerLayout *layout = nil;
    if (!layout)
    {
        layout = [[JoypadControllerLayout alloc] init];
        
        [layout setName: NSLocalizedString(@"Boxer: 4-button racing wheel", @"Label for 4-button wheel Joypad layout.")];
    
        //We use the accelerometer in lieu of onscreen steering controls
        [layout addAccelerometer];
        
        //Gas pedal: blue, rectangular and tall, located along left of screen
        [layout addButtonWithFrame: CGRectMake(380,0,100,320) 
                             label: NSLocalizedString(@"Gas", @"Label for gas pedal on Joypad wheel layouts.")
                          fontSize: 20
                             shape: kJoyButtonShapeSquare
                             color: kJoyButtonColorBlue
                        identifier: kJoyInputLButton];
        
        //Brake pedal: blue, rectangular and tall, located along right of screen
        [layout addButtonWithFrame: CGRectMake(0,0,100,320) 
                             label: NSLocalizedString(@"Brake", @"Label for brake pedal on Joypad wheel layouts.")
                          fontSize: 20
                             shape: kJoyButtonShapeSquare
                             color: kJoyButtonColorBlue
                        identifier: kJoyInputRButton];
        
        //Secondary buttons: circular, arranged in pairs inwards from gas and brake pedals
        [layout addButtonWithFrame: CGRectMake(270,200,90,90) 
                             label: @"1" 
                          fontSize: 36
                             shape: kJoyButtonShapeRound
                             color: kJoyButtonColorBlack
                        identifier: kJoyInputAButton];
        
        [layout addButtonWithFrame: CGRectMake(120,200,90,90) 
                             label: @"2" 
                          fontSize: 36
                             shape: kJoyButtonShapeRound
                             color: kJoyButtonColorBlack
                        identifier: kJoyInputBButton];
        
        [layout addButtonWithFrame: CGRectMake(270,100,90,90) 
                             label: @"3" 
                          fontSize: 36
                             shape: kJoyButtonShapeRound
                             color: kJoyButtonColorBlack
                        identifier: kJoyInputXButton];
        
        [layout addButtonWithFrame: CGRectMake(120,100,90,90) 
                             label: @"4" 
                          fontSize: 36
                             shape: kJoyButtonShapeRound
                             color: kJoyButtonColorBlack
                        identifier: kJoyInputYButton];
        
        //Meta buttons: pill-shaped, located at the top center
        [layout addButtonWithFrame: CGRectMake(120,10,110,30) 
                             label: NSLocalizedString(@"ESC", @"Label for Escape button on Joypad layouts.")
                          fontSize: 12
                             shape: kJoyButtonShapePill
                             color: kJoyButtonColorBlack
                        identifier: kJoyInputStartButton];
        
        [layout addButtonWithFrame: CGRectMake(250,10,110,30) 
                             label: NSLocalizedString(@"PAUSE", @"Label for Pause button on Joypad layouts.")
                          fontSize: 12
                             shape: kJoyButtonShapePill
                             color: kJoyButtonColorBlack
                        identifier: kJoyInputSelectButton];
    }
    return layout;
}
@end
