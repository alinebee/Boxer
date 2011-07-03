/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
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
    
        //NOTE: we omit the additional 2 axes for lack of space
        [layout setName: @"2-axis, 4-button joystick"];
        
        [layout addAnalogStickWithFrame: CGRectMake(0, 70, 240, 240)
                           identifier: kJoyInputAnalogStick1];
        
        /*
        [layout addDpadWithFrame: CGRectMake(0, 70, 240, 240)
                      dpadOrigin: CGPointMake(120, 190)
                      identifier: kJoyInputDpad1];
         */
        
        //Primary buttons: blue, rectangular and tall, located along left of screen
        [layout addButtonWithFrame: CGRectMake(380,100,100,220) 
                           label: @"1" 
                        fontSize: 36
                           shape: kJoyButtonShapeSquare
                           color: kJoyButtonColorBlue
                      identifier: kJoyInputAButton];
        
        [layout addButtonWithFrame: CGRectMake(280,100,100,220) 
                           label: @"2" 
                        fontSize: 36
                           shape: kJoyButtonShapeSquare
                           color: kJoyButtonColorBlue
                      identifier: kJoyInputBButton];
        
        
        //Secondary buttons: black and square, located at top left of screen
        [layout addButtonWithFrame: CGRectMake(380,0,100,100) 
                           label: @"3" 
                        fontSize: 36
                           shape: kJoyButtonShapeSquare
                           color: kJoyButtonColorBlack
                      identifier: kJoyInputXButton];
        
        [layout addButtonWithFrame: CGRectMake(280,0,100,100) 
                           label: @"4" 
                        fontSize: 36
                           shape: kJoyButtonShapeSquare
                           color: kJoyButtonColorBlack
                      identifier: kJoyInputYButton];
        
        //Meta buttons: pill-shaped, located at the top left
        [layout addButtonWithFrame: CGRectMake(20,10,110,30) 
                             label: @"Esc" 
                          fontSize: 16
                             shape: kJoyButtonShapePill
                             color: kJoyButtonColorBlack
                        identifier: kJoyInputStartButton];
        
        [layout addButtonWithFrame: CGRectMake(150,10,110,30) 
                             label: @"Pause" 
                          fontSize: 16
                             shape: kJoyButtonShapePill
                             color: kJoyButtonColorBlack
                        identifier: kJoyInputSelectButton];
    }
    
    return layout;
}
@end
