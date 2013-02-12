/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BX4ButtonJoystickLayout.h"
#import "BXEmulatedJoystick.h"

@implementation BX4ButtonJoystickLayout

+ (void) load
{
	[BXJoypadLayout registerLayout: self forJoystickType: [BX4AxisJoystick class]];
}

+ (JoypadControllerLayout *)layout
{   
    static JoypadControllerLayout *layout = nil;
    if (!layout)
    {
        layout = [[JoypadControllerLayout alloc] init];
    
        [layout setName: NSLocalizedString(@"Boxer: 2-axis, 4-button joystick", @"Label for standard joystick Joypad layout.")];
        
        /*
        [layout addAnalogStickWithFrame: CGRectMake(0, 70, 240, 240)
                           identifier: kJoyInputAnalogStick1];
        */
        
        [layout addDpadWithFrame: CGRectMake(0, 70, 240, 240)
                      identifier: kJoyInputDpad1];
        
        //Primary buttons: blue, rectangular and tall, located along left of screen
        [layout addButtonWithFrame: CGRectMake(380,100,100,220) 
                             label: @"1" 
                          fontSize: 40
                             shape: kJoyButtonShapeSquare
                             color: kJoyButtonColorBlue
                        identifier: kJoyInputAButton];
        
        [layout addButtonWithFrame: CGRectMake(280,100,100,220) 
                             label: @"2" 
                          fontSize: 40
                             shape: kJoyButtonShapeSquare
                             color: kJoyButtonColorBlue
                        identifier: kJoyInputBButton];
        
        
        //Secondary buttons: black and square, located at top left of screen
        [layout addButtonWithFrame: CGRectMake(380,0,100,100) 
                             label: @"3" 
                          fontSize: 28
                             shape: kJoyButtonShapeSquare
                             color: kJoyButtonColorBlack
                        identifier: kJoyInputXButton];
        
        [layout addButtonWithFrame: CGRectMake(280,0,100,100) 
                             label: @"4" 
                          fontSize: 28
                             shape: kJoyButtonShapeSquare
                             color: kJoyButtonColorBlack
                        identifier: kJoyInputYButton];
        
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
