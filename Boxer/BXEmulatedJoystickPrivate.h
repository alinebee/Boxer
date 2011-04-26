//
//  BXEmulatedJoystickPrivate.h
//  Boxer
//
//  Created by Alun Bestor on 26/04/2011.
//  Copyright 2011 Alun Bestor and contributors. All rights reserved.
//

//Private API for use by BXEmulatedJoystick subclasses

#import "BXEmulatedJoystick.h"
#import "BXHIDEvent.h"
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

enum
{	
	BXGameportXAxis,
	BXGameportYAxis
};

enum
{
	BXNoGameportButtonsMask = 0,
	BXGameportButton1Mask = 1U << 0,
	BXGameportButton2Mask = 1U << 1,
	BXGameportButton3Mask = 1U << 2,
	BXGameportButton4Mask = 1U << 3,
	BXAllGameportButtonsMask = BXGameportButton1Mask | BXGameportButton2Mask | BXGameportButton3Mask | BXGameportButton4Mask
};

typedef NSUInteger BXGameportButtonMask;


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
- (void) _releaseButton: (NSNumber *)button;

@end

