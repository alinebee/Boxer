/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BX2ButtonJoystickLayout.h"
#import "BXEmulatedJoystick.h"

@implementation BX2ButtonJoystickLayout

+ (void) load
{
	[BXJoypadLayout registerLayout: self forJoystickType: [BX2AxisJoystick class]];
}

+ (JoypadControllerLayout *)layout
{
    static JoypadControllerLayout *layout = nil;
    if (!layout)
    {
        layout = [[JoypadControllerLayout alloc] init];
        
        [layout setName: NSLocalizedString(@"Boxer: 2-axis, 2-button joystick", @"Label for simple joystick Joypad layout.")];
        
        /*
         [layout addAnalogStickWithFrame: CGRectMake(0, 70, 240, 240)
         identifier: kJoyInputAnalogStick1];
         */
        
        [layout addDpadWithFrame: CGRectMake(0, 70, 240, 240)
                      identifier: kJoyInputDpad1];
        
        //Primary buttons: blue, rectangular and tall, located along left of screen
        [layout addButtonWithFrame: CGRectMake(380,0,100,320) 
                             label: @"1" 
                          fontSize: 36
                             shape: kJoyButtonShapeSquare
                             color: kJoyButtonColorBlue
                        identifier: kJoyInputAButton];
        
        [layout addButtonWithFrame: CGRectMake(280,0,100,320) 
                             label: @"2" 
                          fontSize: 36
                             shape: kJoyButtonShapeSquare
                             color: kJoyButtonColorBlue
                        identifier: kJoyInputBButton];
        
        //Meta buttons: pill-shaped, located at the top left
        [layout addButtonWithFrame: CGRectMake(20,10,110,30) 
                             label: NSLocalizedString(@"ESC", @"Label for Escape button on Joypad layouts.")
                          fontSize: 12
                             shape: kJoyButtonShapePill
                             color: kJoyButtonColorBlack
                        identifier: kJoyInputStartButton];
        
        [layout addButtonWithFrame: CGRectMake(150,10,110,30) 
                             label: NSLocalizedString(@"PAUSE", @"Label for pause button on Joypad layouts.") 
                          fontSize: 12
                             shape: kJoyButtonShapePill
                             color: kJoyButtonColorBlack
                        identifier: kJoyInputSelectButton];
    }
    
    return layout;
}
@end
