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
#import "BXBezelController.h"
#import "BXVideoHandler.h"


#pragma mark -
#pragma mark Constants

//Axis input over this amount will be considered obviously deliberate,
//rather than slop from a loose controller axis. Used by HIDEventIsDeliberate:
#define BXDeliberateAxisInputThreshold DDHID_JOYSTICK_VALUE_MAX / 2


#pragma mark -
#pragma mark Implementation

@implementation BXInputController (BXJoystickInput)
//Synthesized in BXInputController.m, but compiler overlooks that and throws up warnings otherwise
@dynamic availableJoystickTypes;

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
	return [NSSet setWithObjects: @"availableJoystickTypes", @"representedObject.gameSettings.preferredJoystickType", nil];
}

+ (NSSet *) keyPathsForValuesAffectingSelectedJoystickTypeIndexes
{
    //FIXME: selectedJoystickTypeIndexes doesn't depend on or refer to the currently
    //active joystick at all. However, for some as-yet-unknown reason the Inspector's
    //joystick UI won't initially highlight the preferred joystick type when
    //running on 10.7 and when running a gamebox; *unless* we force it to check
    //the value when the actual joystick changes too. Which makes no sense.
    //Programming-by-coincidence-a-go-go.
	return [NSSet setWithObjects: @"joystickType", @"preferredJoystickType", nil];
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

- (NSIndexSet *) selectedJoystickTypeIndexes
{
	NSUInteger typeIndex = NSNotFound;
	Class currentType = [self preferredJoystickType];
    
    //Convert nils into the placeholder type
    if (currentType == nil)
    {
        currentType = [BXNullJoystickPlaceholder class];
    }
    
	if (currentType)
	{
		typeIndex = [[self availableJoystickTypes] indexOfObject: currentType];
	}
	
	if (typeIndex != NSNotFound) return [NSIndexSet indexSetWithIndex: typeIndex];
	else return [NSIndexSet indexSet];
}

- (void) setSelectedJoystickTypeIndexes: (NSIndexSet *)types
{
	NSUInteger typeIndex = [types firstIndex];
	NSArray *availableTypes = [self availableJoystickTypes];
	if (typeIndex != NSNotFound && typeIndex < [availableTypes count])
	{
		Class selectedType = [availableTypes objectAtIndex: typeIndex];
        
		if (selectedType)
		{
            //Convert the nil placeholder into a proper nil
            if ([selectedType isEqual: [BXNullJoystickPlaceholder class]]) selectedType = nil;
            
			[self setPreferredJoystickType: selectedType];
		}
	}
}

- (Class) preferredJoystickType
{
	BXSession *session = [self representedObject];
	NSArray *availableTypes = [self availableJoystickTypes];
    
	Class defaultJoystickType = [availableTypes count] ? [availableTypes objectAtIndex: 0] : nil;
    if (defaultJoystickType == [BXNullJoystickPlaceholder class]) defaultJoystickType = nil;
	
	NSString *className	= [[session gameSettings] objectForKey: @"preferredJoystickType"];
    
	//If no type has been set, then fall back on the default joystick type
	if (!className) return defaultJoystickType;
	
	//If the type was an empty string, this indicates no joystick support
	else if ([className isEqualToString: @""]) return nil;
	
	//Return the specified joystick type class:
    //or the default joystick type, if that class is not currently available
	else
	{
		Class joystickType = NSClassFromString(className);
		if ([availableTypes containsObject: joystickType])
            return joystickType;
		else return defaultJoystickType;
	}
}

- (void) setPreferredJoystickType: (Class)joystickType
{
	if (joystickType != [self preferredJoystickType])
	{
		//Persist the new joystick type into the per-game settings
		NSString *className;
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

		//Reinitialize the joysticks to use the newly-selected joystick type
		[self _syncJoystickType];
	}
}


- (BOOL) joystickControllersAvailable
{
    return [[[[NSApp delegate] joystickController] joystickDevices] count] > 0;
}

- (BOOL) controllersAvailable
{
	return [self joystickControllersAvailable] || [self joypadControllersAvailable];
}

- (void) _syncAvailableJoystickTypes
{
	//Filter joystick options based on the level of game support for them
	BXSession *session = [self representedObject];
	BXJoystickSupportLevel supportLevel = [[session emulator] joystickSupport];
	
	NSArray *types;
	if (supportLevel == BXJoystickSupportFull)
	{
		types = [NSArray arrayWithObjects:
                 [BX4AxisJoystick class],
                 [BXThrustmasterFCS class],
                 [BXCHFlightStickPro class],
                 [BX4AxisWheel class],
                 [BXNullJoystickPlaceholder class],
                 nil];
	}
	else if (supportLevel == BXJoystickSupportSimple)
	{
		types = [NSArray arrayWithObjects:
                 [BX2AxisJoystick class],
                 [BX2AxisWheel class],
                 [BXNullJoystickPlaceholder class],
                 nil];
	}
	else types = [NSArray arrayWithObject: [BXNullJoystickPlaceholder class]];
	
	[self setAvailableJoystickTypes: types];
}

- (void) _syncJoystickType
{
	BXEmulator *emulator = [[self representedObject] emulator];
	BXJoystickSupportLevel support = [emulator joystickSupport];
	
	Class preferredJoystickClass = [self preferredJoystickType];
	
	//If the current game doesn't support joysticks, or the user has chosen
	//to disable joystick support, or there are no real controllers connected,
    //then remove the emulated joystick and don't continue further.
	if (support == BXNoJoystickSupport || !preferredJoystickClass || ![self controllersAvailable])
	{
		[emulator detachJoystick];
	}
	else
    {
		if (![[emulator joystick] isMemberOfClass: preferredJoystickClass])
			[emulator attachJoystickOfType: preferredJoystickClass];
	}
}

- (void) _syncControllerProfiles
{
    id <BXEmulatedJoystick> joystick = [self _emulatedJoystick];
    
    [controllerProfiles removeAllObjects];
    if (joystick)
    {
        NSArray *controllers = [[[NSApp delegate] joystickController] joystickDevices];
        for (DDHidJoystick *controller in controllers)
        {
            BXHIDControllerProfile *profile = [BXHIDControllerProfile profileForHIDController: controller
                                                                           toEmulatedJoystick: joystick];
            
            NSNumber *locationID = [NSNumber numberWithLong: [controller locationId]];
            [controllerProfiles setObject: profile forKey: locationID];
        }
    }
}



#pragma mark -
#pragma mark Handling HID events

+ (BOOL) HIDEventIsDeliberate: (BXHIDEvent *)event
{
    if ([event type] == BXHIDJoystickButtonDown) return YES;
    if ([event POVDirection] != BXHIDPOVCentered) return YES;
    if (ABS([event axisPosition]) > BXDeliberateAxisInputThreshold) return YES;
    return NO;
}


- (BOOL) _activeProgramIsIgnoringJoystick
{
    BXEmulator *emulator = [[self representedObject] emulator];

    //If we've received gameport read signals, then the game isn't ignoring the joystick.
    if ([emulator joystickActive]) return NO;
    
    //If joystick emulation is not active, there's no joystick to ignore.
    if (![self _emulatedJoystick]) return NO;
    
    //If the game doesn't seem to be loaded yet (i.e. is still in text mode),
    //don't consider joystick input as being ignored.
    //(This way we don't bug the user if they're just mucking around on the
    //controller while watching the game load.)
    if ([[emulator videoHandler] isInTextMode]) return NO;
    
    //If we get this far then yes, the current program does seem to be ignoring the joystick.
    return YES;
}


//Send the event on to the controller profile for the specified device
- (void) dispatchHIDEvent: (BXHIDEvent *)event
{
    //If the game is not reading joystick input right now, and the user is making
    //'significant' controller input, show a notification that the game is ignoring them.
    if ([self _activeProgramIsIgnoringJoystick] && [[self class] HIDEventIsDeliberate: event])
    {
        [[BXBezelController controller] showJoystickIgnoredBezel];
    }
    
	DDHidDevice *device = [event device];
	NSNumber *locationID = [NSNumber numberWithLong: [device locationId]];
	
	BXHIDControllerProfile *profile = [controllerProfiles objectForKey: locationID];
	[profile dispatchHIDEvent: event];
}

@end


@implementation BXNullJoystickPlaceholder

+ (NSString *) localizedName
{
    return NSLocalizedString(@"No joystick", @"Localized name for joystick-disabled option.");
}

+ (NSString *) localizedInformativeText
{
    return NSLocalizedString(@"Disable joystick emulation.", @"Localized descriptive text for joystick-disabled option.");
}

+ (NSImage *) icon
{
    return [NSImage imageNamed: @"NoJoystickTemplate"];
}

@end
