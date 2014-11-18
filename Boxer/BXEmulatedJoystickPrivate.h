/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//Private API for use by BXEmulatedJoystick subclasses

#import "BXEmulatedJoystick.h"
#import "ADBHIDEvent.h"
#import "config.h"
#import "joystick.h"


enum
{
	BXGameportStick1,
	BXGameportStick2
};

enum
{	
	BXGameportButton1,
	BXGameportButton2
};

typedef NS_ENUM(NSUInteger, BXGameportAxis)
{	
	BXGameportXAxis,
	BXGameportYAxis,
	BXGameportX2Axis,
	BXGameportY2Axis,
    
    BXWheelWheelAxis            = BXGameportXAxis,
    BXWheelCombinedPedalAxis    = BXGameportYAxis,
    BXWheelAcceleratorAxis      = BXGameportX2Axis,
    BXWheelBrakeAxis            = BXGameportY2Axis
};


typedef NS_OPTIONS(NSUInteger, BXGameportButtonMask)
{
	BXNoGameportButtonsMask = 0,
	BXGameportButton1Mask = 1U << 0,
	BXGameportButton2Mask = 1U << 1,
	BXGameportButton3Mask = 1U << 2,
	BXGameportButton4Mask = 1U << 3,
	BXAllGameportButtonsMask = BXGameportButton1Mask | BXGameportButton2Mask | BXGameportButton3Mask | BXGameportButton4Mask
};


#define BXGameportAxisMin -1.0f
#define BXGameportAxisMax 1.0f
#define BXGameportAxisCentered 0.0f



#pragma mark -
#pragma mark Private method declarations

@interface BXBaseEmulatedJoystick ()

//The pressed/released state of all emulated buttons
@property (assign) BXGameportButtonMask pressedButtons;

//Process the press/release of a joystick button.
- (void) setButton: (BXEmulatedJoystickButton)button
           toState: (BOOL)pressed;

//Called by buttonPressed: after a delay to release the pressed button.
- (void) releaseButton: (NSNumber *)button;

//A helper method for normalizing an 8-way POV direction to the closest cardinal (NSEW) BXEmulatedPOVDirection
//constant, taking into account which cardinal POV direction it was in before. This makes the corners 'sticky',
//so that e.g. N to NE will return N, while E to NE will return E. This reduces unintentional switching.
+ (BXEmulatedPOVDirection) closest4WayDirectionForPOV: (BXEmulatedPOVDirection)direction
                                          previousPOV: (BXEmulatedPOVDirection)oldDirection;

//Move the specified axis to the specified position.
- (void) setPosition: (float)position forGameportAxis: (BXGameportAxis)axis;
- (float) positionForGameportAxis: (BXGameportAxis)axis;

@end

