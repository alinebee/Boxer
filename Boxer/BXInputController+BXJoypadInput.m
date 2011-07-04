/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXInputControllerPrivate.h"
#import "BXSession+BXEmulatorControls.h"
#import "BXAppController.h"
#import "BXJoypadController.h"
#import "BXJoypadLayout.h"
#import "JoypadSDK.h"
#import "BXEmulatedKeyboard.h"

//Deadzone for Joypad wheel emulation: devices within +/- this number will be treated as centered.
#define BXJoypadRotationDeadzone 0.15f

//The +/- Z angle beyond which Boxer will treat the phone as resting and ignore input from it.
#define BXJoypadRestingThreshold 0.9f

//The maximum scale of movement for the analog stick.
//TODO: figure out what lies behind this constant
#define BXJoypadAnalogStickMaxDistance 55.0f


@implementation BXInputController (BXJoypadInput)

+ (NSUInteger) emulatedJoystickButtonForJoypadButton: (JoyInputIdentifier)button
{
    switch (button)
    {
        case kJoyInputAButton:
            return BXEmulatedJoystickButton1;
            
        case kJoyInputBButton:
            return BXEmulatedJoystickButton2;
            
        case kJoyInputXButton:
            return BXEmulatedJoystickButton3;
            
        case kJoyInputYButton:
            return BXEmulatedJoystickButton4;
            
        default:
            return NSNotFound;
    }
}

+ (NSSet *) keyPathsForValuesAffectingCurrentJoypadLayout
{
    return [NSSet setWithObject: @"preferredJoystickType"];
}

- (JoypadControllerLayout *) currentJoypadLayout
{
    Class joystickType = [self preferredJoystickType];
    if (joystickType)
    {
        return [BXJoypadLayout layoutForJoystickType: joystickType];
    }
    else return nil;
}

- (BOOL) joypadControllersAvailable
{
    return [[[NSApp delegate] joypadController] hasJoypadDevices];
}


- (void) joypadDevice: (JoypadDevice *)device
        didAccelerate: (JoypadAcceleration)accel
{
    float roll, pitch;
    
    //These will have a range in radians from PI to -PI.
    double roll_in_radians  = atan2(accel.y, -accel.x);
    double pitch_in_radians = atan2(accel.z, -accel.x);
    
    //PI/2 (90 degrees counterclockwise) to -PI/2 (90 degrees clockwise)
    //is what we want to map to the -1.0 to 1.0 range of the emulated joystick.
    //(We don't need to worry about the overflow to -+2.0, because the emulated
    //joystick automatically crops axis values to +-1.0)
    roll = -(float)(roll_in_radians / M_PI_2);
    pitch = -(float)(pitch_in_radians / M_PI_2);
    
    id joystick = [self _emulatedJoystick];
    
    //Map roll to steering
    if ([joystick respondsToSelector: @selector(wheelMovedTo:)])
    {
        //Apply a deadzone to the center of the wheel range
        if (ABS(roll) < BXJoypadRotationDeadzone) roll = 0.0f;
        
        [joystick wheelMovedTo: roll];
    }
    //Map roll and pitch to X and Y axes
    else if ([joystick respondsToSelector: @selector(xAxisMovedTo:)] &&
             [joystick respondsToSelector: @selector(yAxisMovedTo:)])
    {
        //Normally 0.0 pitch is completely vertical, +1.0 pitch is horizontal.
        //We want our pitch's 0 resting position to be at about 45 degrees,
        //and to avoid the user having to push all the way to horizontal as
        //that will prevent us taking roll readings.
        //The calculation below will give us 0 at 45 degrees from horizontal,
        //-1.0 at about 80 degrees from horizontal and 1.0 at about 10 degrees
        //from horizontal.
        pitch = (pitch - 0.5f) * 2.5f;
        
        //Apply a deadzone to the center of each axis
        if (ABS(roll) < BXJoypadRotationDeadzone)   roll = 0.0f;
        if (ABS(pitch) < BXJoypadRotationDeadzone)  pitch = 0.0f;
        
        [joystick xAxisMovedTo: roll];
        [joystick yAxisMovedTo: pitch];
    }
}

- (void) joypadDevice: (JoypadDevice *)device
                 dPad: (JoyInputIdentifier)dpad
             buttonUp: (JoyDpadButton)dpadButton
{
    id joystick = [self _emulatedJoystick];
    
    if ([joystick respondsToSelector: @selector(POVChangedTo:)])
    {
        
    }
    else if ([joystick respondsToSelector: @selector(xAxisMovedTo:)] && 
             [joystick respondsToSelector: @selector(yAxisMovedTo:)])
    {
        switch (dpadButton)
        {
            case kJoyDpadButtonUp:
            case kJoyDpadButtonDown:
                [joystick yAxisMovedTo: 0.0f];
                break;
                
            case kJoyDpadButtonLeft:
            case kJoyDpadButtonRight:
                [joystick xAxisMovedTo: 0.0f];
                break;
        }
    } 
}

- (void) joypadDevice: (JoypadDevice *)device
                 dPad: (JoyInputIdentifier)dpad
           buttonDown: (JoyDpadButton)dpadButton
{
    
    id joystick = [self _emulatedJoystick];
    
    if ([joystick respondsToSelector: @selector(POVChangedTo:)])
    {
        
    }
    else if ([joystick respondsToSelector: @selector(xAxisMovedTo:)] && 
             [joystick respondsToSelector: @selector(yAxisMovedTo:)])
    {
        switch (dpadButton)
        {
            case kJoyDpadButtonUp:
                [joystick yAxisMovedTo: -1.0f];
                break;
            case kJoyDpadButtonDown:
                [joystick yAxisMovedTo: 1.0f];
                break;
                
            case kJoyDpadButtonLeft:
                [joystick xAxisMovedTo: -1.0f];
                break;
            case kJoyDpadButtonRight:
                [joystick xAxisMovedTo: 1.0f];
                break;
        }
    }  
}

- (void) joypadDevice: (JoypadDevice *)device
             buttonUp: (JoyInputIdentifier)button
{
    id joystick = [self _emulatedJoystick];
    BXEmulatedKeyboard *keyboard = [self _emulatedKeyboard];
    switch (button)
    {
        case kJoyInputRButton:
            //Accelerator pedal
            if ([joystick respondsToSelector: @selector(acceleratorMovedTo:)])
                [joystick acceleratorMovedTo: 0.0f];
            break;
        
        case kJoyInputLButton:
            //Gas pedal
            if ([joystick respondsToSelector: @selector(brakeMovedTo:)])
                [joystick brakeMovedTo: 0.0f];
            break;
            
        case kJoyInputSelectButton:
            //Pause button
            //Do nothing on button up: this is a toggle
            break;
            
        case kJoyInputStartButton:
            //ESC button
            [keyboard keyUp: KBD_esc];
                
        default:
        {
            NSUInteger joyButton = [[self class] emulatedJoystickButtonForJoypadButton: button];
        
            if (joyButton != NSNotFound)
                [joystick buttonUp: joyButton];
        }
    }
}

- (void) joypadDevice: (JoypadDevice *)device
           buttonDown: (JoyInputIdentifier)button
{
    id joystick = [self _emulatedJoystick];
    BXEmulatedKeyboard *keyboard = [self _emulatedKeyboard];
    switch (button)
    {
        case kJoyInputRButton:
            //Accelerator pedal
            if ([joystick respondsToSelector: @selector(acceleratorMovedTo:)])
                [joystick acceleratorMovedTo: 1.0f];
            break;
            
        case kJoyInputLButton:
            //Gas pedal
            if ([joystick respondsToSelector: @selector(brakeMovedTo:)])
                [joystick brakeMovedTo: 1.0f];
            break;
            
        case kJoyInputSelectButton:
            //Pause button
            [[self representedObject] togglePaused: self];
            break;
            
        case kJoyInputStartButton:
            //ESC button
            [keyboard keyDown: KBD_esc];
            
        default:
        {
            NSUInteger joyButton = [[self class] emulatedJoystickButtonForJoypadButton: button];
            
            if (joyButton != NSNotFound)
                [joystick buttonDown: joyButton];
        }
    }
}

- (void) joypadDevice: (JoypadDevice *)device
          analogStick: (JoyInputIdentifier)stick
              didMove: (JoypadStickPosition)newPosition
{
    id joystick = [self _emulatedJoystick];
    
    if ([joystick respondsToSelector: @selector(xAxisMovedTo:)] &&
        [joystick respondsToSelector: @selector(yAxisMovedTo:)])
    {
        //Joypad SDK provides stick position as polar coordinates
        //(angle and distance); we need to convert this to cartesian
        //(x, y) coordinates for emulated joystick.
        float scale = newPosition.distance / BXJoypadAnalogStickMaxDistance;
        float x = cosf(newPosition.angle) * scale;
        float y = -sinf(newPosition.angle) * scale;
        
        [joystick xAxisMovedTo: x];
        [joystick yAxisMovedTo: y];
        
        //NSLog(@"%f, %f", x, y);
    }
}

@end
