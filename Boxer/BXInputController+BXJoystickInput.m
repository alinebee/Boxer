/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXInputControllerPrivate.h"
#import "BXAppController.h"
#import "BXJoystickController.h"
#import "BXHIDControllerProfile.h"


@implementation BXInputController (BXJoystickInput)

#pragma mark -
#pragma mark Setting and getting joystick configuration


+ (NSSet *) keyPathsForValuesAffectingStrictGameportTiming
{
	return [NSSet setWithObject: @"representedObject.emulator.gameportTimingMode"];
}

+ (NSSet *) keyPathsForValuesAffectingJoystickType
{
	return [NSSet setWithObject: @"representedObject.emulator.joystick"];
}

+ (NSSet *) keyPathsForValuesAffectingPreferredJoystickType
{
	return [NSSet setWithObject: @"representedObject.gameSettings.preferredJoystickType"];
}

- (BOOL) strictGameportTiming
{
	BXEmulator *emulator = [[self representedObject] emulator];
	return [emulator gameportTimingMode] == BXGameportTimingClockBased;
}

- (void) setStrictGameportTiming: (BOOL)flag
{
	BXSession *session = [self representedObject];
	BXEmulator *emulator = [session emulator];
	
	BXGameportTimingMode mode = (flag) ? BXGameportTimingClockBased : BXGameportTimingPollBased;
	if ([emulator gameportTimingMode] != flag)
	{
		[emulator setGameportTimingMode: mode];
		
		//Preserve changes in the per-game settings
		[[session gameSettings] setObject: [NSNumber numberWithBool: flag] forKey: @"strictGameportTiming"];
	}
}

- (Class) joystickType
{
	BXSession *session	= [self representedObject];
	return [[[session emulator] joystick] class];
}

- (void) setJoystickType: (Class)joystickType
{
	[self setPreferredJoystickType: joystickType];
}

- (Class) preferredJoystickType
{
	BXSession *session	= [self representedObject];
	
	Class defaultJoystickType = [BX4AxisJoystick class];
	
	NSString *className	= (NSString *)[[session gameSettings] objectForKey: @"preferredJoystickType"];
	
	//If no setting exists, then fall back on the default joystick type
	if (!className) return defaultJoystickType;
	
	//Setting was an empty string, indicating no joystick support
	else if (![className length]) return nil;
	
	//Otherwise return the specified joystick type class (or the default joystick type, if no such class exists)
	else
	{
		Class joystickType = NSClassFromString(className);
		if (joystickType) return joystickType;
		else return defaultJoystickType;
	}
}

- (void) setPreferredJoystickType: (Class)joystickType
{
	if (joystickType != [self preferredJoystickType])
	{
		NSString *className;
		//Persist the new joystick type into the per-game settings
		if (joystickType != nil)
		{
			className = NSStringFromClass(joystickType);
		}
		else
		{
			className = @"";
		}
		NSMutableDictionary *gameSettings = [[self representedObject] gameSettings];
		[gameSettings setObject: className forKey: @"preferredJoystickType"];
		
		//Reinitialize the joysticks
		[self _syncJoystickType];
	}
}

- (BOOL) validatePreferredJoystickType: (id *)ioValue error: (NSError **)outError
{
	Class joystickClass = *ioValue;
	
	//Nil values are just fine, skip all the other checks 
	if (!joystickClass) return YES;
	
	//Unknown classname or non-joystick class
	if (![joystickClass conformsToProtocol: @protocol(BXEmulatedJoystick)])
	{
		if (outError)
		{
			NSString *descriptionFormat = NSLocalizedString(@"“%@” is not a valid joystick type.",
															@"Format for error message when choosing an unrecognised joystick type. %@ is the classname of the chosen joystick type.");
			
			NSString *description = [NSString stringWithFormat: descriptionFormat, NSStringFromClass(joystickClass), nil];
			
			NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  description, NSLocalizedDescriptionKey,
									  joystickClass, BXEmulatedJoystickClassKey,
									  nil];
			
			*outError = [NSError errorWithDomain: BXEmulatedJoystickErrorDomain
											code: BXEmulatedJoystickInvalidType
										userInfo: userInfo];
		}
		return NO;
	}
	
	/* Disabled for now: this needs to be moved downstream into BXEmulator, because the preferred joystick type can be set at any time.
	BXEmulator *emulator = [[self representedObject] emulator];
	
	//Joystick class valid but not supported by the current session
	if ([emulator joystickSupport] == BXNoJoystickSupport || 
		([emulator joystickSupport] == BXJoystickSupportSimple && [joystickClass requiresFullJoystickSupport]))
	{
		if (outError)
		{
			NSString *localizedName	= [joystickClass localizedName];
			NSString *sessionName	= [[self representedObject] displayName];
			
			NSString *descriptionFormat = NSLocalizedString(@"Joysticks of type “%1$@” are not supported by %2$@.",
															@"Format for error message when choosing an unsupported joystick type. %1$@ is the localized name of the chosen joystick type, %2$@ is the display name of the current DOS session.");
			
			NSString *description = [NSString stringWithFormat: descriptionFormat, localizedName, sessionName, nil];
			
			NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  description, NSLocalizedDescriptionKey,
									  joystickClass, BXEmulatedJoystickClassKey,
									  nil];
			
			*outError = [NSError errorWithDomain: BXEmulatedJoystickErrorDomain
											code: BXEmulatedJoystickUnsupportedType
										userInfo: userInfo];
		}
		return NO; 
	}
	 */
	
	//Joystick type is fine, go ahead
	return YES;
}


- (void) _syncJoystickType
{
	BXEmulator *emulator = [[self representedObject] emulator];
	BXJoystickSupportLevel support = [emulator joystickSupport];
	
	Class preferredJoystickClass = [self preferredJoystickType];
	
	//If the current game doesn't support joysticks at all, or the user
	//has chosen to disable joystick support, then remove all connected
	//joysticks and don't continue further.
	if (support == BXNoJoystickSupport || !preferredJoystickClass)
	{
		[emulator detachJoystick];
		return;
	}
	
	NSArray *controllers = [[[NSApp delegate] joystickController] joystickDevices];
	NSUInteger numControllers = [controllers count];
	
	if (numControllers > 0)
	{
		Class joystickClass;
		
		//TODO: ask BXEmulator to validate the specified class, and fall back on the 2-axis joystick otherwise
		if (support == BXJoystickSupportFull)
		{
			joystickClass = preferredJoystickClass;
		}
		else joystickClass = [BX2AxisJoystick class];
		
		if (![[emulator joystick] isMemberOfClass: joystickClass])
			[emulator attachJoystickOfType: joystickClass];
		
		//Record which of the devices will be considered the main input device
		primaryController = [controllers objectAtIndex: 0];
		
		//Regenerate controller profiles for each controller
		for (DDHidJoystick *controller in controllers)
		{
			BXHIDControllerProfile *profile = [BXHIDControllerProfile profileForHIDController: controller
																		   toEmulatedJoystick: [emulator joystick]];
			NSNumber *locationID = [NSNumber numberWithLong: [controller locationId]];
			[controllerProfiles setObject: profile forKey: locationID];
		}
	}
	else
	{
		[emulator detachJoystick];
		primaryController = nil;
	}
}


#pragma mark -
#pragma mark Handling HID events

//Send the event on to the controller profile for the specified device
- (void) dispatchHIDEvent: (BXHIDEvent *)event
{
	DDHidDevice *device = [event device];
	NSNumber *locationID = [NSNumber numberWithLong: [device locationId]];
	
	BXHIDControllerProfile *profile = [controllerProfiles objectForKey: locationID];
	[profile dispatchHIDEvent: event];
}

@end
