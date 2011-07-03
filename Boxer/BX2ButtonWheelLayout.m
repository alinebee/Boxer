/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BX2ButtonWheelLayout.h"
#import "BXEmulatedJoystick.h"


@implementation BX2ButtonWheelLayout

+ (void) load
{
	[BXJoypadLayout registerLayout: self forJoystickType: [BX2AxisWheel class]];
}

+ (JoypadControllerLayout *)layout
{
    JoypadControllerLayout *layout = [BXJoypadLayout layout];
    
    [layout setName: @"2-button racing wheel"];
    
    //We use the accelerometer in lieu of onscreen steering controls
    [layout addAccelerometer];
    
    //Gas pedal: blue, rectangular and tall, located along left of screen
    [layout addButtonWithFrame: CGRectMake(380,0,100,320) 
                       label: @"Gas" 
                    fontSize: 20
                       shape: kJoyButtonShapeSquare
                       color: kJoyButtonColorBlue
                  identifier: kJoyInputLButton];
    
    //Brake pedal: blue, rectangular and tall, located along right of screen
    [layout addButtonWithFrame: CGRectMake(0,0,100,320) 
                       label: @"Brake" 
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
    
    return layout;
}
@end
