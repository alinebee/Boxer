/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXInputPanelController.h"
#import "BXEmulatedJoystick.h"
#import "BXSession.h"
#import "BXEmulator.h"


@implementation BXInputPanelController
@synthesize joystickTypeSelector, sessionMediator;

- (BXSession *) session
{
	return [[self sessionMediator] content];
}

- (void) dealloc
{
	[self setSessionMediator: nil]; [sessionMediator release];
	[self setJoystickTypeSelector: nil]; [joystickTypeSelector release];
	[super dealloc];
}

- (NSArray *) joystickTypes
{
	return [NSArray arrayWithObjects:
			[BX2AxisJoystick class],
			[BX4AxisJoystick class],
			[BXThrustmasterFCS class],
			//[BXCHFlightStickPro class],
			//[BXCHCombatStick class],
			nil];
}

- (void) menuWillOpen: (NSMenu *)menu
{
	//Validate the available joystick types
	BXJoystickSupportLevel supportLevel = [[[self session] emulator] joystickSupport];
	
	for (NSMenuItem *menuItem in [menu itemArray])
	{
		Class joystickClass = [menuItem representedObject];
		if (joystickClass)
		{
			BOOL enable =	(supportLevel == BXJoystickSupportFull) ||
							(supportLevel == BXJoystickSupportSimple && ![joystickClass requiresFullJoystickSupport]);
			
			[menuItem setEnabled: enable];
		}
	}
}
@end
