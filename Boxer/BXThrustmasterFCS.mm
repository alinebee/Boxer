/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXEmulatedJoystickPrivate.h"


#pragma mark -
#pragma mark Constants

//The Thrustmaster FCS used various positions on the Y2 axis to represent its hat switch.
//These positions are adapted from:
//http://www.epanorama.net/documents/joystick/pc_special.html#tmfcs

#define BXThrustmasterFCSPOVNorth		-1.0f
#define BXThrustmasterFCSPOVEast		-0.5f
#define BXThrustmasterFCSPOVSouth		0.0f
#define BXThrustmasterFCSPOVWest		0.5f
#define BXThrustmasterFCSPOVCentered	1.0f

//The amount of leeway to use when mapping an axis value back to a POV-switch constant.
//Used by BXThrustmasterFCS -POVDirection.
#define BXThrustmasterFCSPOVThreshold 0.25f


#pragma mark -
#pragma mark Implementation

@implementation BXThrustmasterFCS

+ (NSString *) localizedName
{	
	return NSLocalizedString(@"Thrustmaster FCS",
							 @"Localized name for Thrustmaster FCS joystick type.");
}

+ (NSString *) localizedInformativeText
{
	return NSLocalizedString(@"4 buttons, POV hat and rudder pedals.\nSuitable for flight sims.",
							 @"Localized informative text for Thrustmaster FCS joystick type.");
}

+ (NSImage *) icon
{
	return [NSImage imageNamed: @"ThrustmasterFCS"];
}

+ (BOOL) requiresFullJoystickSupport { return YES; }


- (NSUInteger) numButtons		{ return 4; }
- (NSUInteger) numAxes			{ return 3; } //Y2 axis is reserved for the POV switch
- (NSUInteger) numPOVSwitches	{ return 1; }

- (void) clearInput
{
	JOYSTICK_Move_X(BXGameportStick1, BXGameportAxisCentered);
	JOYSTICK_Move_Y(BXGameportStick1, BXGameportAxisCentered);
	JOYSTICK_Move_X(BXGameportStick2, BXGameportAxisCentered);
	//Set the hat axis to its proper center position
	JOYSTICK_Move_Y(BXGameportStick2, BXThrustmasterFCSPOVCentered);
}

- (void) POVChangedTo: (BXEmulatedPOVDirection)direction
{
	BXEmulatedPOVDirection normalizedDirection = [BXHIDEvent closest4WayDirectionForPOV: direction
																			previousPOV: [self POVDirection]];
	
	float axisValue = BXThrustmasterFCSPOVCentered;
	switch (normalizedDirection)
	{
		case BXEmulatedPOVNorth:
			axisValue = BXThrustmasterFCSPOVNorth;
			break;
			
		case BXEmulatedPOVEast:
			axisValue = BXThrustmasterFCSPOVEast;
			break;
		
		case BXEmulatedPOVSouth:
			axisValue = BXThrustmasterFCSPOVSouth;
			break;
			
		case BXEmulatedPOVWest:
			axisValue = BXThrustmasterFCSPOVWest;
			break;
	}
	
	[self axis: BXThrustmasterFCSHatAxis movedTo: axisValue];
}

- (BXEmulatedPOVDirection) POVDirection
{
	float axisValue = [self axisPosition: BXThrustmasterFCSHatAxis];	// Value from -1.0 to 1.0
	float threshold = axisValue + BXThrustmasterFCSPOVThreshold;		// Value from -0.75 to 1.25
	
	if (threshold > BXThrustmasterFCSPOVCentered)	return BXEmulatedPOVCentered;
	if (threshold > BXThrustmasterFCSPOVWest)		return BXEmulatedPOVWest;
	if (threshold > BXThrustmasterFCSPOVSouth)		return BXEmulatedPOVSouth;
	if (threshold > BXThrustmasterFCSPOVEast)		return BXEmulatedPOVEast;
	return BXEmulatedPOVNorth;
}

- (void) rudderMovedTo: (float)position		{ [self axis: BXThrustmasterFCSRudderAxis movedTo: position]; }
- (void) rudderMovedBy: (float)delta		{ [self axis: BXThrustmasterFCSRudderAxis movedBy: delta]; }

//The Y2 axis is reserved for the hat, so we ignore regular input on it
//TODO: remove our inheritance from BX4AxisJoystick so this isn't necessary
- (void) y2AxisMovedTo: (float)position {}
- (void) y2AxisMovedBy: (float)delta {}
@end
