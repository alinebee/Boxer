/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXSession+BXEmulatorController.h"
#import "BXAppController.h"
#import "BXEmulator+BXRendering.h"
#import "BXEmulator+BXRecording.h"
#import "BXEmulator+BXShell.h"
#import "BXEmulator+BXInput.h"
#import "BXValueTransformers.h"
#import "BXVideoFormatAlert.h"


@implementation BXSession (BXEmulatorController)

//Speed-related class methods
//---------------------------

+ (void) initialize
{
	BXBandedValueTransformer *speedBanding		= [[BXBandedValueTransformer new] autorelease];
	BXInvertNumberTransformer *invertFramerate	= [[BXInvertNumberTransformer new] autorelease];
	
	NSArray *bands = [NSArray arrayWithObjects:
		[NSNumber numberWithInteger: BXMinSpeedThreshold],
		[NSNumber numberWithInteger: BX286SpeedThreshold],
		[NSNumber numberWithInteger: BX386SpeedThreshold],
		[NSNumber numberWithInteger: BX486SpeedThreshold],
		[NSNumber numberWithInteger: BXPentiumSpeedThreshold],
		[NSNumber numberWithInteger: BXMaxSpeedThreshold],
	nil];
	
	[speedBanding setBandThresholds: bands];
	
	[NSValueTransformer setValueTransformer: speedBanding forName:@"BXSpeedSliderTransformer"];
	[NSValueTransformer setValueTransformer: invertFramerate forName:@"BXFrameRateSliderTransformer"];
}

//We use different increment scales depending on the speed, to give more accuracy to low-speed adjustments
+ (NSInteger) incrementAmountForSpeed: (NSInteger)speed goingUp: (BOOL) increasing
{
	speed += increasing;
	if (speed > BXPentiumSpeedThreshold)	return BXPentiumSpeedIncrement;
	if (speed > BX486SpeedThreshold)		return BX486SpeedIncrement;
	if (speed > BX386SpeedThreshold)		return BX386SpeedIncrement;
	if (speed > BX286SpeedThreshold)		return BX286SpeedIncrement;
											return BXMinSpeedIncrement;
}

+ (NSInteger) snappedSpeed: (NSInteger) rawSpeed
{
	NSInteger increment = [self incrementAmountForSpeed: rawSpeed goingUp: YES];
	return (NSInteger)(round((CGFloat)rawSpeed / increment) * increment);
}

+ (NSString *) cpuClassFormatForSpeed: (NSInteger)speed
{
	if (speed >= BXPentiumSpeedThreshold)	return NSLocalizedString(@"Pentium speed (%u)",	@"Description for Pentium speed class. %u is cycles setting.");
	if (speed >= BX486SpeedThreshold)		return NSLocalizedString(@"486 speed (%u)",		@"Description for 80486 speed class. %u is cycles setting.");
	if (speed >= BX386SpeedThreshold)		return NSLocalizedString(@"386 speed (%u)",		@"Description for 80386 speed class. %u is cycles setting.");
	if (speed >= BX286SpeedThreshold)		return NSLocalizedString(@"AT speed (%u)",		@"Description for PC-AT 80286 speed class. %u is cycles setting.");
	
	return NSLocalizedString(@"XT speed (%u)",		@"Description for PC-XT 8088 speed class. %u is cycles setting.");
}


//Class methods affecting binding
//-------------------------------

+ (NSSet *) keyPathsForValuesAffectingMouseLocked			{ return [NSSet setWithObject: @"emulator.mouseLocked"]; }
+ (NSSet *) keyPathsForValuesAffectingSliderSpeed			{ return [NSSet setWithObjects: @"emulator.fixedSpeed", @"emulator.autoSpeed", nil]; }

+ (NSSet *) keyPathsForValuesAffectingSpeedDescription		{ return [NSSet setWithObject: @"sliderSpeed"]; }
+ (NSSet *) keyPathsForValuesAffectingFrameskipDescription	{ return [NSSet setWithObject: @"emulator.frameskip"]; }


//Responding to actions
//---------------------

- (IBAction) pause: (id)sender
{
	[[self emulator] setPaused: ![[self emulator] isPaused]];
}

- (IBAction) takeScreenshot: (id)sender
{
	[[self emulator] recordImage];
	[[NSApp delegate] playUISoundWithName: @"Snapshot" atVolume: 0.5f];
}

- (IBAction) toggleRecordingVideo: (id)sender
{
	BOOL isRecording = [[self emulator] isRecordingVideo];
	[[self emulator] setRecordingVideo: !isRecording];

	//If we stopped recording, check whether the new video file exists and can be played by the user
	//(If not, prompt the user to download Perian)
	if (isRecording)
	{
		NSFileManager *manager		= [NSFileManager defaultManager];
		NSUserDefaults *defaults	= [NSUserDefaults standardUserDefaults];
		NSString *recordingPath		= [[self emulator] currentRecordingPath];
		if (![defaults boolForKey: @"suppressCodecRequiredAlert"] && [manager fileExistsAtPath: recordingPath])
		{
			//We check if our video format is supported only once per application session,
			//since the check is slow and the result won't change over the lifetime of the app
			static NSInteger formatSupported = -1;
			
			if (formatSupported == -1) formatSupported = (NSInteger)[[BXEmulator class] canPlayVideoRecording: recordingPath];
			if (!formatSupported)
			{
				BXVideoFormatAlert *alert = [BXVideoFormatAlert alert];
				[alert beginSheetModalForWindow: [self windowForSheet] contextInfo: nil];
			}
		}
	}
}

- (IBAction) incrementFrameSkip: (id)sender
{
	
	NSNumber *newFrameskip = [NSNumber numberWithInteger: [[self emulator] frameskip] + 1];
	if ([[self emulator] validateFrameskip: &newFrameskip error: nil])
		[[self emulator] setFrameskip: [newFrameskip integerValue]];
}

- (IBAction) decrementFrameSkip: (id)sender
{
	NSNumber *newFrameskip = [NSNumber numberWithInteger: [[self emulator] frameskip] - 1];
	if ([[self emulator] validateFrameskip: &newFrameskip error: nil])
		[[self emulator] setFrameskip: [newFrameskip integerValue]];
}

- (IBAction) incrementSpeed: (id)sender
{
	if ([self speedAtMaximum]) return;
	
	NSInteger currentSpeed = [[self emulator] fixedSpeed];
	
	if (currentSpeed >= [[self emulator] maxFixedSpeed]) [[self emulator] setAutoSpeed: YES];
	else
	{
		NSInteger increment	= [[self class] incrementAmountForSpeed: currentSpeed goingUp: YES];
		//This snaps the speed to the nearest increment rather than doing straight addition
		increment -= (currentSpeed % increment);
		
		//Validate our final value before assigning it
		NSNumber *newSpeed = [NSNumber numberWithInteger: currentSpeed + increment];
		if ([[self emulator] validateFixedSpeed: &newSpeed error: nil])
			[[self emulator] setFixedSpeed: [newSpeed integerValue]];
	}
}

- (IBAction) decrementSpeed: (id)sender
{
	if ([self speedAtMinimum]) return;
	
	if ([[self emulator] isAutoSpeed])
	{
		[[self emulator] setFixedSpeed: [[self emulator] maxFixedSpeed]];
	}
	else
	{
		NSInteger currentSpeed	= [[self emulator] fixedSpeed];
		NSInteger increment		= [[self class] incrementAmountForSpeed: currentSpeed goingUp: NO];
		//This snaps the speed to the nearest increment rather than doing straight subtraction
		NSInteger diff			= (currentSpeed % increment);
		if (diff) increment		= diff;
		
		//Validate our final value before assigning it
		NSNumber *newSpeed = [NSNumber numberWithInteger: currentSpeed - increment];
		if ([[self emulator] validateFixedSpeed: &newSpeed error: nil])
			[[self emulator] setFixedSpeed: [newSpeed integerValue]];
	}
}

- (BOOL) validateUserInterfaceItem: (id)theItem
{
	//All our actions depend on the emulator being active
	if (![[self emulator] isExecuting]) return NO;
	
	SEL theAction = [theItem action];
	BOOL hideItem;

	if (theAction == @selector(incrementSpeed:))		return ![self speedAtMaximum];
	if (theAction == @selector(decrementSpeed:))		return ![self speedAtMinimum];

	if (theAction == @selector(incrementFrameSkip:))	return ![self frameskipAtMaximum];
	if (theAction == @selector(decrementFrameSkip:))	return ![self frameskipAtMinimum];

	//Defined in BXFileManager
	if (theAction == @selector(openInDOS:))				return [[self emulator] isAtPrompt];

	//if (theAction == @selector(paste:))	return [self canPaste];
	
	if (theAction == @selector(toggleRecordingVideo:))
	{
		if ([theItem isKindOfClass: [NSMenuItem class]])
		{
			NSString *title;
			if (![[self emulator] isRecordingVideo])
				title = NSLocalizedString(@"Start Recording Video", @"Recording menu option for starting video recording.");
			else
				title = NSLocalizedString(@"Stop Recording Video", @"Recording menu option for stopping video recording.");
			
			[theItem setTitle: title];
		}
	}
	
	return [super validateUserInterfaceItem: theItem];
}


//Used to selectively enable/disable menu items by validateUserInterfaceItem
- (BOOL) speedAtMinimum		{ return ![[self emulator] isAutoSpeed] && [[self emulator] fixedSpeed] <= [[self emulator] minFixedSpeed]; }
- (BOOL) speedAtMaximum		{ return [[self emulator] isAutoSpeed]; }

- (BOOL) frameskipAtMinimum	{ return [[self emulator] frameskip] <= 0; }
- (BOOL) frameskipAtMaximum	{ return [[self emulator] frameskip] >= [[self emulator] maxFrameskip]; }


//Keyboard events
//---------------

- (IBAction) sendEnter: (id)sender	{ [[self emulator] sendEnter]; }
- (IBAction) sendF1:	(id)sender	{ [[self emulator] sendF1]; }
- (IBAction) sendF2:	(id)sender	{ [[self emulator] sendF2]; }
- (IBAction) sendF3:	(id)sender	{ [[self emulator] sendF3]; }
- (IBAction) sendF4:	(id)sender	{ [[self emulator] sendF4]; }
- (IBAction) sendF5:	(id)sender	{ [[self emulator] sendF5]; }
- (IBAction) sendF6:	(id)sender	{ [[self emulator] sendF6]; }
- (IBAction) sendF7:	(id)sender	{ [[self emulator] sendF7]; }
- (IBAction) sendF8:	(id)sender	{ [[self emulator] sendF8]; }
- (IBAction) sendF9:	(id)sender	{ [[self emulator] sendF9]; }
- (IBAction) sendF10:	(id)sender	{ [[self emulator] sendF10]; }


//Handling paste
//--------------

/*
- (IBAction) paste: (id)sender
{
	NSPasteboard *pboard = [NSPasteboard generalPasteboard];

	if ([[pboard types] containsObject: NSStringPboardType])
	{
		NSString *pastedString = [pboard stringForType: NSStringPboardType];
		[self handlePastedString: pastedString];
	}
}

- (BOOL) canPaste
{
	return NO;	//Disabled for now
	NSPasteboard *pboard = [NSPasteboard generalPasteboard];
	return [[pboard types] containsObject: NSStringPboardType];
}

//Yes that's right, we handle pasting by generating key events for each pasted character. Wheeee!
//TODO: we need to look up hardware goddamn keycodes
//Fuck everything
- (BOOL) handlePastedString: (NSString *)pastedString
{
	if ([[self emulator] isExecuting])
	{
		NSString *cleanedString = [pastedString stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
		NSUInteger numChars = [cleanedString length];
		
		NSWindow *window = [[self mainWindowController] window];
		NSUInteger windowNumber = [window windowNumber];
		
		NSEvent *downEvent, *upEvent;
		NSString *subString;
		NSRange range;
		NSUInteger i;
		
		for (i = 0; i < numChars; i++)
		{
			range = NSMakeRange(i, 1);
			subString = [cleanedString substringWithRange: range];
			
			downEvent = [NSEvent
				keyEventWithType:	NSKeyDown
				location:			NSZeroPoint
				modifierFlags:		0
				timestamp:			0
				windowNumber:		windowNumber
				context:			nil
				characters:			subString
				charactersIgnoringModifiers: subString
				isARepeat:			NO
				keyCode:			0
			];
			
			upEvent = [NSEvent
				keyEventWithType:	NSKeyUp
				location:			NSZeroPoint
				modifierFlags:		NSShiftKeyMask
				timestamp:			0
				windowNumber:		windowNumber
				context:			nil
				characters:			subString
				charactersIgnoringModifiers: subString
				isARepeat:			NO
				keyCode:			0
			];
		
			[NSApp postEvent: downEvent atStart: NO];
			[NSApp postEvent: upEvent atStart: NO];
		}
	}
	return YES;
}
*/
 

//Wrapping mouse-lock state
//-------------------------
//We pass along the mouselock state unhindered, but just play a cheery sound to accompany it

- (void) setMouseLocked: (BOOL) lock
{
	[[self emulator] setMouseLocked: lock];	
	if ([self mouseLocked] == lock)
	{
		NSString *lockSoundName	= (lock) ? @"LockClosing" : @"LockOpening";
		[[NSApp delegate] playUISoundWithName: lockSoundName atVolume: 0.5f];
	}
}
- (BOOL) mouseLocked { return [[self emulator] mouseLocked]; }



//Wrapping CPU speed state
//------------------------
//We wrap the slider's speed value so that we can snap it to the nearest increment, and also switch to auto-throttled speed when it hits the highest speed setting

- (void) setSliderSpeed: (NSInteger)speed
{	
	//If we're at the maximum speed, bump it into auto-throttling mode
	if (speed >= [[self emulator] maxFixedSpeed]) [[self emulator] setAutoSpeed: YES];
	
	//Otherwise, set the fixed speed
	else [[self emulator] setFixedSpeed: speed];
}

- (NSInteger) sliderSpeed
{
	//Report the max fixed speed if we're in auto-throttling mode
	
	return ([[self emulator] isAutoSpeed]) ? [[self emulator] maxFixedSpeed] : [[self emulator] fixedSpeed];
}

//Snap fixed speed to even increments, unless the Option key is held down
- (BOOL)validateSliderSpeed: (id *)ioValue error: (NSError **)outError
{
	if (!([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask))
	{
		NSInteger speed			= [*ioValue integerValue]; 
		NSInteger snappedSpeed	= [[self class] snappedSpeed: speed];
		*ioValue = [NSNumber numberWithInteger: snappedSpeed];
	}
	return YES;
}


//Descriptions for emulation settings
//-----------------------------------

- (NSString *) speedDescription
{	
	if (![[self emulator] isExecuting]) return @"";

	if ([[self emulator] isAutoSpeed])
		return NSLocalizedString(@"Maximized speed", @"Description for current CPU speed when in automatic CPU throttling mode.");
	else
	{
		NSInteger speed		= [[self emulator] fixedSpeed];
		NSString *format	= [[self class] cpuClassFormatForSpeed: speed];
		return [NSString stringWithFormat: format, speed];
	}
}

- (NSString *) frameskipDescription
{
	if (![[self emulator] isExecuting]) return @"";
	
	NSString *format;
	NSUInteger frameskip = [[self emulator] frameskip]; 
	if (frameskip == 0)
			format = NSLocalizedString(@"Playing every frame",		@"Descriptive text for 0 frameskipping");
	else	format = NSLocalizedString(@"Playing 1 in %u frames",	@"Descriptive text for >0 frameskipping");
	
	return [NSString stringWithFormat: format, frameskip + 1];
}
@end