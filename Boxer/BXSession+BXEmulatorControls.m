/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXSessionPrivate.h"
#import "BXEmulator+BXShell.h"
#import "BXEmulator+BXPaste.h"
#import "BXEmulator+BXAudio.h"
#import "BXValueTransformers.h"
#import "BXBaseAppController+BXSupportFiles.h"
#import "BXVideoHandler.h"
#import "BXDOSWindow.h"
#import "BXCloseAlert.h"
#import "BXGamebox.h"
#import "NSAlert+BXAlert.h"

#import "BXDOSWindowController.h"
#import "BXInputController.h"
#import "BXBezelController.h"

#import "NSImage+BXSaveImages.h"
#import "BXFileTypes.h"


@implementation BXSession (BXEmulatorControls)

#pragma mark -
#pragma mark Speed-related helper methods

+ (void) initialize
{
    //Do not reinitialize in subclasses
    if (self == [BXSession class])
    {   
        NSDateFormatter *screenshotDateFormatter = [[NSDateFormatter alloc] init];
        screenshotDateFormatter.dateFormat = NSLocalizedString(@"yyyy-MM-dd 'at' h.mm.ss a", @"The date and time format to use for screenshot filenames. Literal strings (such as the 'at') should be enclosed in single quotes. The date order should not be changed when localizing unless really necessary, as this is important to maintain chronological ordering in alphabetical file listings. Note that some characters such as / and : are not permissible in filenames and will be stripped out or replaced.");
        
        double bands[6] = {
            BXMinSpeedThreshold,
            BX286SpeedThreshold,
            BX386SpeedThreshold,
            BX486SpeedThreshold,
            BXPentiumSpeedThreshold,
            BXMaxSpeedThreshold
        };
        NSValueTransformer *speedBanding		= [[BXBandedValueTransformer alloc] initWithThresholds: bands count: 6];
        NSValueTransformer *invertFramerate     = [[BXInvertNumberTransformer alloc] init];
        NSValueTransformer *screenshotDater     = [[BXDateTransformer alloc] initWithDateFormatter: screenshotDateFormatter];
        
        
        [NSValueTransformer setValueTransformer: speedBanding forName: @"BXSpeedSliderTransformer"];
        [NSValueTransformer setValueTransformer: invertFramerate forName: @"BXFrameRateSliderTransformer"];
        [NSValueTransformer setValueTransformer: screenshotDater forName: @"BXScreenshotDateTransformer"];
        
        [speedBanding release];
        [invertFramerate release];
        [screenshotDater release];
        [screenshotDateFormatter release];
    }
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
	if (speed >= BXPentiumSpeedThreshold)	return NSLocalizedString(@"Pentium speed (%u cycles)",	@"Description for Pentium speed class. %u is cycles setting.");
	if (speed >= BX486SpeedThreshold)		return NSLocalizedString(@"486 speed (%u cycles)",		@"Description for 80486 speed class. %u is cycles setting.");
	if (speed >= BX386SpeedThreshold)		return NSLocalizedString(@"386 speed (%u cycles)",		@"Description for 80386 speed class. %u is cycles setting.");
	if (speed >= BX286SpeedThreshold)		return NSLocalizedString(@"AT speed (%u cycles)",		@"Description for PC-AT 80286 speed class. %u is cycles setting.");
	
	return NSLocalizedString(@"XT speed (%u cycles)",		@"Description for PC-XT 8088 speed class. %u is cycles setting.");
}

+ (NSString *) descriptionForSpeed: (NSInteger)speed
{
    if (speed == BXAutoSpeed)
    	return NSLocalizedString(@"Maximum speed", @"Description for current CPU speed when in automatic CPU throttling mode.");
    
    else
        return [NSString stringWithFormat: [self cpuClassFormatForSpeed: speed], speed];
}

#pragma mark -
#pragma mark Controlling CPU emulation

- (IBAction) pause: (id)sender
{
    if (self.isEmulating && !self.isPaused)
    {
        self.paused = YES;
        //Disable fast-forward upon pausing.
        self.emulator.turboSpeed = NO;
        [[BXBezelController controller] showPauseBezel];
    }
}

- (IBAction) resume: (id)sender
{
    if (self.isEmulating && self.isPaused)
    {
        self.paused = NO;
        //Disable fast-forward upon resuming.
        self.emulator.turboSpeed = NO;
        [[BXBezelController controller] showPlayBezel];
    }
}

- (IBAction) togglePaused: (id)sender
{
    if (self.isPaused)
        [self resume: sender];
    else
        [self pause: sender];
}

- (NSUInteger) frameskip
{
	return self.emulator.videoHandler.frameskip;
}

- (void) setFrameskip: (NSUInteger)frameskip
{
	self.emulator.videoHandler.frameskip = frameskip;
	
	[self.gameSettings setObject: [NSNumber numberWithUnsignedInteger: frameskip]
                          forKey: @"frameskip"];
}

- (BOOL) validateFrameskip: (id *)ioValue error: (NSError **)outError
{
	NSUInteger theValue = [*ioValue unsignedIntegerValue];
	if (theValue > BXMaxFrameskip)
        *ioValue = [NSNumber numberWithUnsignedInteger: BXMaxFrameskip];
    
	return YES;
}

- (IBAction) incrementFrameSkip: (id)sender
{
	NSNumber *newFrameskip = [NSNumber numberWithInteger: self.frameskip + 1];
	if ([self validateFrameskip: &newFrameskip error: nil])
		self.frameskip = newFrameskip.integerValue;
}

- (IBAction) decrementFrameSkip: (id)sender
{
	NSNumber *newFrameskip = [NSNumber numberWithInteger: self.frameskip - 1];
	if ([self validateFrameskip: &newFrameskip error: nil])
		self.frameskip = newFrameskip.integerValue;
}


- (BOOL) isAutoSpeed
{
	return self.emulator.isAutoSpeed;
}

- (void) setAutoSpeed: (BOOL)isAuto
{
    self.emulator.autoSpeed = isAuto;
    //Upon changing the emulator speed, turn off fast-forward.
    self.emulator.turboSpeed = NO;
	
	//Preserve changes to the speed settings
	[self.gameSettings setObject: [NSNumber numberWithInteger: BXAutoSpeed]
                          forKey: @"CPUSpeed"];
}

- (NSInteger) CPUSpeed
{
	return self.emulator.isAutoSpeed ? BXAutoSpeed : self.emulator.fixedSpeed;
}

- (void) setCPUSpeed: (NSInteger)speed
{
    if (speed == BXAutoSpeed)
    {
        self.autoSpeed = YES;
    }
    else
    {
        self.autoSpeed = NO;
        self.emulator.fixedSpeed = speed;
        
        //Upon changing the emulator speed, turn off fast-forward.
        self.emulator.turboSpeed = NO;
        
        [self.gameSettings setObject: [NSNumber numberWithInteger: speed]
                              forKey: @"CPUSpeed"];
    }
}

- (BOOL) validateCPUSpeed: (id *)ioValue error: (NSError **)outError
{
	NSInteger theValue = [*ioValue integerValue];
    if (theValue != BXAutoSpeed)
    {
        if		(theValue < BXMinSpeedThreshold) *ioValue = [NSNumber numberWithInteger: BXMinSpeedThreshold];
        else if	(theValue > BXMaxSpeedThreshold) *ioValue = [NSNumber numberWithInteger: BXMaxSpeedThreshold];
    }
	return YES;
}

- (IBAction) incrementSpeed: (id)sender
{
	if (self.speedAtMaximum) return;
	
	NSInteger currentSpeed = self.CPUSpeed;
	
	if (currentSpeed >= BXMaxSpeedThreshold) self.autoSpeed = YES;
	else
	{
		NSInteger increment	= [self.class incrementAmountForSpeed: currentSpeed goingUp: YES];
		//This snaps the speed to the nearest increment rather than doing straight addition
		increment -= (currentSpeed % increment);
		
		//Validate our final value before assigning it
		NSNumber *newSpeed = [NSNumber numberWithInteger: currentSpeed + increment];
		if ([self validateCPUSpeed: &newSpeed error: nil])
			self.CPUSpeed = newSpeed.integerValue;
	}
    
    [[BXBezelController controller] showCPUSpeedBezelForSpeed: self.CPUSpeed];
}

- (IBAction) decrementSpeed: (id)sender
{
	if (self.speedAtMinimum) return;
	
	if (self.isAutoSpeed)
	{
		self.CPUSpeed = BXMaxSpeedThreshold;
	}
	else
	{
		NSInteger currentSpeed	= self.CPUSpeed;
		NSInteger increment		= [self.class incrementAmountForSpeed: currentSpeed goingUp: NO];
		//This snaps the speed to the nearest increment rather than doing straight subtraction
		NSInteger diff			= currentSpeed % increment;
		if (diff) increment = diff;
		
		//Validate our final value before assigning it
		NSNumber *newSpeed = [NSNumber numberWithInteger: currentSpeed - increment];
		if ([self validateCPUSpeed: &newSpeed error: nil])
			self.CPUSpeed = newSpeed.integerValue;
	}
    
    [[BXBezelController controller] showCPUSpeedBezelForSpeed: self.CPUSpeed];
}



- (IBAction) toggleFastForward: (id)sender
{
    if (!self.emulating) return;
    
    //Check if the menu option was triggered via its key equivalent or via a regular click.
    NSEvent *currentEvent = [NSApp currentEvent];
    
    //If the toggle was triggered by a key event, then trigger the fast-forward until the key is released.
    if (currentEvent.type == NSKeyDown)
    {
        [self fastForward: sender];
        
        if (self.emulator.isConcurrent)
        {
            //Keep fast-forwarding until the user lifts the key. Once we receive the key-up,
            //then discard all the repeated key-down events that occurred before the key-up:
            //otherwise, the action will trigger again and again for each repeat.
            NSEvent *keyUp = [NSApp nextEventMatchingMask: NSKeyUpMask
                                                untilDate: [NSDate distantFuture]
                                                   inMode: NSEventTrackingRunLoopMode
                                                  dequeue: NO];
            [NSApp discardEventsMatchingMask: NSKeyDownMask beforeEvent: keyUp];
            [self releaseFastForward: sender];
        }
        else
        {
            //IMPLEMENTATION NOTE: when the emulator is running on the main thread,
            //an event-tracking loop like the one above would block the emulation:
            //defeating the purpose of the fast-forward. So instead, we listen for
            //the key-up within the session's event-dispatch loop: making it a kind
            //of inverted tracking loop.
            _waitingForFastForwardRelease = YES;
        }
    }
    //If the option was toggled by a regular menu click, then make it 'stick' until toggled again.
    else
    {
        if (!self.emulator.turboSpeed)
        {
            [self fastForward: sender];
        }
        else
        {
            [self releaseFastForward: sender];
        }
        _waitingForFastForwardRelease = NO;
    }
}

- (IBAction) fastForward: (id)sender
{
    if (!self.isEmulating) return;
    
    //Unpause when fast-forwarding
    [self resume: self];
    
    if (!self.emulator.turboSpeed)
    {
        self.emulator.turboSpeed = YES;
        
        [[BXBezelController controller] showFastForwardBezel];
    }
}
        
- (IBAction) releaseFastForward: (id)sender
{
    if (self.emulator.turboSpeed || _waitingForFastForwardRelease)
    {
        if (self.isEmulating)
            self.emulator.turboSpeed = NO;
        
        BXBezelController *bezel = [BXBezelController controller];
        if (bezel.currentBezel == bezel.fastForwardBezel)
            [bezel hideBezel];
        
        _waitingForFastForwardRelease = NO;
    }
}


- (void) setSliderSpeed: (NSInteger)speed
{
	//If we're at the maximum speed, bump it into auto-throttling mode
	if (speed >= BXMaxSpeedThreshold) speed = BXAutoSpeed;
	self.CPUSpeed = speed;
}

- (NSInteger) sliderSpeed
{
	//Report the max fixed speed if we're in auto-throttling mode,
    //so that the knob will appear at the top end of the slider
    //instead of the bottom
	return (self.isAutoSpeed) ? BXMaxSpeedThreshold : self.CPUSpeed;
}

//Snap fixed speed to even increments, unless the Option key is held down
- (BOOL) validateSliderSpeed: (id *)ioValue error: (NSError **)outError
{
	if (!([NSApp currentEvent].modifierFlags & NSAlternateKeyMask))
	{
		NSInteger speed			= [*ioValue integerValue]; 
		NSInteger snappedSpeed	= [self.class snappedSpeed: speed];
		*ioValue = [NSNumber numberWithInteger: snappedSpeed];
	}
	return YES;
}


- (BOOL) isDynamic	{ return self.emulator.coreMode == BXCoreDynamic; }

- (void) setDynamic: (BOOL)dynamic
{
	self.emulator.coreMode = dynamic ? BXCoreDynamic : BXCoreNormal;
	
	[self.gameSettings setObject: [NSNumber numberWithInteger: self.emulator.coreMode]
                          forKey: @"coreMode"];
}


- (BOOL) validateUserInterfaceItem: (id <NSValidatedUserInterfaceItem>)theItem
{
	//All our actions depend on the emulator being active
	if (!self.isEmulating) return NO;
	
	SEL theAction = theItem.action;
    
    BOOL isShowingDOSView = (self.DOSWindowController.currentPanel == BXDOSWindowDOSView);
        
	if (theAction == @selector(incrementSpeed:))		return isShowingDOSView && !self.speedAtMaximum;
	if (theAction == @selector(decrementSpeed:))		return isShowingDOSView && !self.speedAtMinimum;

	if (theAction == @selector(incrementFrameSkip:))	return isShowingDOSView && !self.frameskipAtMaximum;
	if (theAction == @selector(decrementFrameSkip:))	return isShowingDOSView && !self.frameskipAtMinimum;
    
	if (theAction == @selector(saveScreenshot:))		return isShowingDOSView;
    
	if (theAction == @selector(openInDOS:))				return self.emulator.isAtPrompt;
	if (theAction == @selector(revertShadowedChanges:)) return self.hasShadowedChanges;
	if (theAction == @selector(mergeShadowedChanges:))  return self.hasShadowedChanges;
    
    if (theAction == @selector(exportGameState:))   return self.hasShadowedChanges;
	if (theAction == @selector(importGameState:))   return self.hasGamebox;
    
    if (theAction == @selector(printDocument:) || theAction == @selector(orderFrontPrintStatusPanel:))
        return self.emulator.printer != nil;
    
	if (theAction == @selector(paste:))
		return isShowingDOSView && [self canPasteFromPasteboard: [NSPasteboard generalPasteboard]];
	
	return [super validateUserInterfaceItem: theItem];
}

- (NSAttributedString *) _menuItemLabelForDrive: (BXDrive *)drive
                                  withBaseTitle: (NSString *)baseTitle
{
    //Display drive titles smaller and greyed out.
    //We use a transcluent black rather than the system grey color, so that
    //it gets properly inverted to white when the menu item is selected.
    NSDictionary *driveTitleAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSFont menuFontOfSize: [NSFont smallSystemFontSize]], NSFontAttributeName,
                                     [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.5f], NSForegroundColorAttributeName,
                                     nil];
    
    //Display the base title in the standard menu font. We need to explicitly set this
    //because NSAttributedString defaults to Helvetica 12pt, and not Lucida Grande 14pt
    //(the proper menu font.)
    NSDictionary *baseTitleAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont menuFontOfSize: 14], NSFontAttributeName,
                                    nil];
    
    NSString *separator = @"  ";
    NSMutableAttributedString *title = [[NSMutableAttributedString alloc] initWithString: [baseTitle stringByAppendingString: separator]
                                                                              attributes: baseTitleAttrs];
    
    NSAttributedString *driveTitle = [[NSAttributedString alloc] initWithString: drive.title
                                                                     attributes: driveTitleAttrs];
    
    [title appendAttributedString: driveTitle];
    [driveTitle release];
    
    return [title autorelease];
}

- (BOOL) validateMenuItem: (NSMenuItem *)theItem
{
	SEL theAction = theItem.action;
	
    BOOL isShowingDOSView = (self.DOSWindowController.currentPanel == BXDOSWindowDOSView);
    
    NSString *title;
    //Pause menu item
	if (theAction == @selector(togglePaused:))
	{
		if (!self.isPaused)
			title = NSLocalizedString(@"Pause", @"Emulation menu option for pausing the emulator.");
		else
			title = NSLocalizedString(@"Resume", @"Emulation menu option for resuming from pause.");
		
        theItem.title = title;
        
		return self.isEmulating && isShowingDOSView;
	}
    //Menu item to switch to next disc in queue
    else if (theAction == @selector(mountNextDrivesInQueues:))
    {
        if (self.isEmulating)
        {
            //Figure out the drive that will be switched to by the menu item,
            //and append its title to that of the menu item.
            for (BXDrive *currentDrive in self.mountedDrives)
            {
                BXDrive *nextDrive = [self siblingOfQueuedDrive: currentDrive atOffset: 1];
                if (nextDrive && ![nextDrive isEqual: currentDrive])
                {
                    if (nextDrive.isCDROM)
                        title = NSLocalizedString(@"Next Disc", @"Menu item for cycling to the next queued CD-ROM.");
                    else
                        title = NSLocalizedString(@"Next Disk", @"Menu item for cycling to the next queued floppy or hard disk.");
                                       
                    theItem.attributedTitle = [self _menuItemLabelForDrive: nextDrive withBaseTitle: title];
                    return YES;
                }
            }
        }
        
        //If no next drive is found, or we're not emulating, then disable the menu item altogether and reset its title.
        theItem.title = NSLocalizedString(@"Next Disc", @"Menu item for cycling to the next queued CD-ROM.");
        return NO;
    }
    //Menu item to switch to previous disc in queue
    else if (theAction == @selector(mountPreviousDrivesInQueues:))
    {
        if (self.isEmulating)
        {
            //Figure out the drive that will be switched to by the menu item,
            //and append its title to that of the menu item.
            for (BXDrive *currentDrive in self.mountedDrives)
            {
                BXDrive *previousDrive = [self siblingOfQueuedDrive: currentDrive atOffset: -1];
                if (previousDrive && ![previousDrive isEqual: currentDrive])
                {
                    if (previousDrive.isCDROM)
                        title = NSLocalizedString(@"Previous Disc", @"Menu item for cycling to the previous queued CD-ROM.");
                    else
                        title = NSLocalizedString(@"Previous Disk", @"Menu item for cycling to the previous queued floppy or hard disk.");
                    
                    theItem.attributedTitle = [self _menuItemLabelForDrive: previousDrive
                                                             withBaseTitle: title];
                    return YES;
                }
            }
        }
        
        //If no previous drive is found, then disable the menu item altogether.
        //If no next drive is found, then disable the menu item altogether and reset its title.
        theItem.title = NSLocalizedString(@"Previous Disc", @"Menu item for cycling to the previous queued CD-ROM.");
        return NO;
    }
    //Fast-forward/resume menu item
    else if (theAction == @selector(toggleFastForward:))
    {
		if (!self.emulator.isTurboSpeed)
			title = NSLocalizedString(@"Fast Forward", @"Emulation menu option for fast-forwarding the emulator.");
		else
			title = NSLocalizedString(@"Normal Speed", @"Emulation menu option for returning from fast-forward.");
		
		theItem.title = title;
        
        //TWEAK: disable the menu item while we're waiting for the user to release the key.
        //That will break out of the menu's own key-event loop, which would otherwise block.
		return self.isEmulating && isShowingDOSView && !_waitingForFastForwardRelease;
    }
    //Restart menu item
    else if (theAction == @selector(performRestartAtLaunchPanel:))
    {
        //Disable the option if the current session does not support the launch panel
        //or if we're already at the launch panel.
        return self.isEmulating && self.allowsLauncherPanel && (self.DOSWindowController.currentPanel != BXDOSWindowLaunchPanel);
    }
    
    return YES;
}


//Used to selectively enable/disable menu items by validateUserInterfaceItem
- (BOOL) speedAtMinimum		{ return !self.isAutoSpeed && (self.CPUSpeed <= BXMinSpeedThreshold); }
- (BOOL) speedAtMaximum		{ return self.isAutoSpeed; }

- (BOOL) frameskipAtMinimum	{ return self.frameskip <= 0; }
- (BOOL) frameskipAtMaximum	{ return self.frameskip >= BXMaxFrameskip; }


#pragma mark -
#pragma mark Copy-paste

- (IBAction) paste: (id)sender
{
    //If we're not currently displaying the DOS prompt, disallow pasting.
    BOOL isShowingDOSView = (self.DOSWindowController.currentPanel == BXDOSWindowDOSView);
    if (isShowingDOSView)
    {
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];

        NSArray *acceptedPasteTypes = [NSArray arrayWithObjects: NSFilenamesPboardType, NSStringPboardType, nil];
        NSString *bestType = [pboard availableTypeFromArray: acceptedPasteTypes];
        NSString *pastedString;
        
        if (!bestType) return;
        if ([bestType isEqualToString: NSFilenamesPboardType])
        {
            NSArray *filePaths = [pboard propertyListForType: NSFilenamesPboardType];
            pastedString = filePaths.lastObject;
        }
        else pastedString = [pboard stringForType: NSStringPboardType];
        
        //Unpause when pasting strings
        [self resume: self];
        
        [self.emulator handlePastedString: pastedString asCommand: YES];
    }
}

- (BOOL) canPasteFromPasteboard: (NSPasteboard *)pboard 
{
	NSArray *acceptedPasteTypes = [NSArray arrayWithObjects: NSFilenamesPboardType, NSStringPboardType, nil];
	NSString *bestType = [pboard availableTypeFromArray: acceptedPasteTypes];
	NSString *pastedString;
	
	if (!bestType) return NO;
	if ([bestType isEqualToString: NSFilenamesPboardType])
	{
		NSArray *filePaths = [pboard propertyListForType: NSFilenamesPboardType];
		pastedString = filePaths.lastObject;
	}
	else pastedString = [pboard stringForType: NSStringPboardType];
	return [self.emulator canAcceptPastedString: pastedString];
}


#pragma mark -
#pragma mark Describing emulation state

- (NSString *) speedDescription
{	
	if (!self.isEmulating) return @"";
    return [self.class descriptionForSpeed: self.CPUSpeed];
}

- (NSString *) frameskipDescription
{
	if (!self.isEmulating) return @"";
	
	NSString *format;
	if (self.frameskip == 0)
			format = NSLocalizedString(@"Playing every frame",		@"Descriptive text for 0 frameskipping");
	else	format = NSLocalizedString(@"Playing 1 in %u frames",	@"Descriptive text for >0 frameskipping");
	
	return [NSString stringWithFormat: format, self.frameskip + 1];
}

+ (NSSet *) keyPathsForValuesAffectingSliderSpeed			{ return [NSSet setWithObjects: @"emulating", @"CPUSpeed", @"autoSpeed", @"dynamic", nil]; }
+ (NSSet *) keyPathsForValuesAffectingSpeedDescription		{ return [NSSet setWithObject: @"sliderSpeed"]; }
+ (NSSet *) keyPathsForValuesAffectingFrameskipDescription	{ return [NSSet setWithObjects: @"emulating", @"frameskip", nil]; }


#pragma mark -
#pragma mark Recording

- (IBAction) saveScreenshot: (id)sender
{   
    NSImage *screenshot = [self.DOSWindowController screenshotOfCurrentFrame];
    if (screenshot)
    {
        //Work out an appropriate filename, based on the window title and the current date and time.
        NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName: @"BXScreenshotDateTransformer"];
        NSString *formattedDate = [transformer transformedValue: [NSDate date]];
        
        NSString *nameFormat = NSLocalizedString(@"%1$@ %2$@.png",
                                                 @"Filename pattern for screenshots: %1$@ is the display name of the DOS session, %2$@ is the current date and time in a notation suitable for chronologically-ordered filenames.");
        
        NSString *windowTitle = self.DOSWindowController.window.title;
        NSString *fileName = [NSString stringWithFormat: nameFormat, windowTitle, formattedDate];
        
        //Sanitise the filename in case it contains characters that are disallowed for file paths.
        //TODO: move this off to an NSFileManager/NSString category.
        fileName = [fileName stringByReplacingOccurrencesOfString: @":" withString: @"-"];
        fileName = [fileName stringByReplacingOccurrencesOfString: @"/" withString: @"-"];
        
        NSString *basePath = [[NSApp delegate] recordingsPathCreatingIfMissing: YES];
        NSString *destination = [basePath stringByAppendingPathComponent: fileName];
        
        BOOL saved = [screenshot saveToPath: destination
                                   withType: NSPNGFileType
                                 properties: nil
                                      error: nil];
        
        if (saved)
        {
            NSDictionary *attrs	= [NSDictionary dictionaryWithObject: [NSNumber numberWithBool: YES]
                                                              forKey: NSFileExtensionHidden];
            
            [[NSFileManager defaultManager] setAttributes: attrs ofItemAtPath: destination error: nil];
            
            [[NSApp delegate] playUISoundWithName: @"Snapshot" atVolume: 1.0f];
            [[BXBezelController controller] showScreenshotBezel];
        }
    }
}


#pragma mark -
#pragma mark Filesystem and emulation operations

- (IBAction) performRestart: (id)sender
{
    [self _performRestartShowingLaunchPanel: NO];
}

- (IBAction) performRestartAtLaunchPanel: (id)sender
{
    [self _performRestartShowingLaunchPanel: YES];
}

- (void) _performRestartShowingLaunchPanel: (BOOL)showLaunchPanel
{
    BOOL hasActiveImports = self.isImportingDrives;
    
	//We confirm the close if a process is running and if we're not already shutting down
	BOOL shouldConfirm = hasActiveImports ||
    (![[NSUserDefaults standardUserDefaults] boolForKey: @"suppressCloseAlert"]
     && self.emulator.isRunningProcess
     && !self.emulator.isCancelled);
    
    if (shouldConfirm)
    {
        BXCloseAlert *confirmation;
        
        if (showLaunchPanel)
            confirmation = [BXCloseAlert restartAlertWhenReturningToLaunchPanel: self];
        else if (hasActiveImports)
            confirmation = [BXCloseAlert restartAlertWhileImportingDrives: self];
        else
            confirmation = [BXCloseAlert restartAlertWhileSessionIsEmulating: self];
        
        [confirmation beginSheetModalForWindow: self.windowForSheet
                                 modalDelegate: self
                                didEndSelector: @selector(_restartConfirmationDidEnd:returnCode:contextInfo:)
                                   contextInfo: (void *)showLaunchPanel];
    }
    //If we're already at the DOS prompt then go ahead and restart already.
    else
    {
        [self restartShowingLaunchPanel: showLaunchPanel];
    }    
}

- (void) _restartConfirmationDidEnd: (NSAlert *)alert
                         returnCode: (NSInteger)returnCode
                        contextInfo: (void *)contextInfo
{
    if (returnCode == NSAlertFirstButtonReturn)
    {
        BOOL showLaunchPanel = (BOOL)contextInfo;
        [self restartShowingLaunchPanel: showLaunchPanel];
    }
}


- (IBAction) revertShadowedChanges: (id)sender
{
    //Only proceed if we actually have something to revert.
    if (self.hasShadowedChanges)
    {
        NSAlert *confirmation = [[NSAlert alloc] init];
        
        //We use slightly different terms to refer to the operation depending on whether we’re
        //a standalone game-app or not.
        if ([[NSApp delegate] isStandaloneGameBundle])
        {
            NSString *messageFormat = NSLocalizedString(@"Do you want to reset %@ to its original state?",
                                                        @"Bold text of confirmation when reverting a standalone game app to its original state. %@ is the name of the app.");
            
            confirmation.messageText = [NSString stringWithFormat: messageFormat, self.displayName];
            
            confirmation.informativeText = NSLocalizedString(@"Your savegames and player data will be lost.",
                                                             @"Informative text of confirmation when reverting a standalone game app to its original state.");
            
            NSString *closeLabel	= NSLocalizedString(@"Reset and Relaunch", @"Label for button to confirm that the user wants to revert a standalone game app to its original state.");
            NSString *cancelLabel	= NSLocalizedString(@"Cancel",	@"Cancel the current action and return to what the user was doing");
            
            [confirmation addButtonWithTitle: closeLabel];
            //Ensure the cancel button always uses Escape
            [confirmation addButtonWithTitle: cancelLabel].keyEquivalent = @"\e";
        }
        else
        {
            NSString *messageFormat = NSLocalizedString(@"Do you want to revert %@ to its original state?",
                                                        @"Bold text of confirmation when reverting the current session to its original state. %@ is the display name of the session.");
            
            confirmation.messageText = [NSString stringWithFormat: messageFormat, self.displayName];
            
            confirmation.informativeText = NSLocalizedString(@"Your savegames and file modifications will be lost.",
                                                             @"Informative text of confirmation when reverting the current session to its original state.");
            
            NSString *closeLabel	= NSLocalizedString(@"Revert and Relaunch", @"Label for button to confirm that the user wants to revert the current session to its original state.");
            NSString *cancelLabel	= NSLocalizedString(@"Cancel",	@"Cancel the current action and return to what the user was doing");
            
            [confirmation addButtonWithTitle: closeLabel];
            //Ensure the cancel button always uses Escape
            [confirmation addButtonWithTitle: cancelLabel].keyEquivalent = @"\e";
        }
        
        
        [confirmation adoptIconFromWindow: self.windowForSheet];
        
        [confirmation beginSheetModalForWindow: self.windowForSheet
                                 modalDelegate: self
                                didEndSelector: @selector(_revertConfirmationDidEnd:returnCode:contextInfo:)
                                   contextInfo: NULL];
        
        [confirmation release];
    }
}

- (IBAction) mergeShadowedChanges: (id)sender
{
    //Only proceed if we actually have something to revert.
    if (self.hasShadowedChanges)
    {
        NSAlert *confirmation = [[NSAlert alloc] init];
        
        NSString *messageFormat = NSLocalizedString(@"Do you want to merge your changes into %@?",
                                                    @"Bold text of confirmation when merging shadowed changes for the current session. %@ is the display name of the session.");
        
        confirmation.messageText = [NSString stringWithFormat: messageFormat, self.displayName];
        
        confirmation.informativeText = NSLocalizedString(@"Your savegames and file modifications will become a permanent part of the gamebox for all users.",
                                                         @"Informative text of confirmation when merging shadowed changes for the current session.");
        
		NSString *closeLabel	= NSLocalizedString(@"Merge and Relaunch", @"Label for button to confirm that the user wants to merge their shadowed changes for the current session.");
		NSString *cancelLabel	= NSLocalizedString(@"Cancel", @"Cancel the current action and return to what the user was doing");
        
        [confirmation addButtonWithTitle: closeLabel];
        //Ensure the cancel button always uses Escape
		[confirmation addButtonWithTitle: cancelLabel].keyEquivalent = @"\e";
        
        [confirmation adoptIconFromWindow: self.windowForSheet];
        
        [confirmation beginSheetModalForWindow: self.windowForSheet
                                 modalDelegate: self
                                didEndSelector: @selector(_mergeConfirmationDidEnd:returnCode:contextInfo:)
                                   contextInfo: NULL];
        
        [confirmation release];
    }
}

- (void) _revertConfirmationDidEnd: (NSAlert *)alert
                        returnCode: (NSInteger)returnCode
                       contextInfo: (void *)contextInfo
{
    if (returnCode == NSAlertFirstButtonReturn)
    {
        //The user has given their OK, so go ahead with the reversion.
        NSError *revertError;
        BOOL reverted = [self revertChangesForAllDrivesAndReturnError: &revertError];
        
        //Once reversion is completed, restart the session to complete the operation.
        if (reverted)
        {
            [self restartShowingLaunchPanel: NO];
        }
        
        //If reversion failed, tell the user the reason and restart the app afterward.
        else
        {
            if (revertError)
            {
                //In order to display the error to the user,
                //we need to get the confirmation sheet out of the way.
                [self.windowForSheet.attachedSheet orderOut: self];
                
                //Note that unlike with, we don't call our _shadow. We assume that the import operation
                //did not affect the existing files.
                [self presentError: revertError
                    modalForWindow: self.windowForSheet
                          delegate: self
                didPresentSelector: NULL
                       contextInfo: NULL];
            }
        }
    }
}

- (void) _mergeConfirmationDidEnd: (NSAlert *)alert
                       returnCode: (NSInteger)returnCode
                      contextInfo: (void *)contextInfo
{
    if (returnCode == NSAlertFirstButtonReturn)
    {
        //The user has given their OK, so go ahead with the merge.
        NSError *mergeError;
        BOOL merged = [self mergeChangesForAllDrivesAndReturnError: &mergeError];
        
        //Once merging is completed, restart the app to complete the operation.
        if (merged)
        {
            [self restartShowingLaunchPanel: NO];
        }
        
        //If the merge failed, tell the user the reason and restart the app afterward.
        else
        {
            if (mergeError)
            {
                //In order to display the error to the user,
                //we need to get the confirmation sheet out of the way.
                [self.windowForSheet.attachedSheet orderOut: self];
                
                [self presentError: mergeError
                    modalForWindow: self.windowForSheet
                          delegate: self
                didPresentSelector: @selector(_didPresentShadowOperationErrorWithRecovery:contextInfo:)
                       contextInfo: NULL];
            }
        }
    }
}

- (IBAction) importGameState: (id)sender
{
    //Don't continue if this session doesn't support importing
    if (!self.hasGamebox)
        return;
    
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.title = NSLocalizedString(@"Import game data",
                                    @"Title for open panel when importing a game state");
    panel.prompt = NSLocalizedString(@"Import and Relaunch",
                                     @"Label for confirmation button on open panel when importing a game state.");
    panel.message = NSLocalizedString(@"Importing will replace your current savegames and player data. The game will relaunch to complete the import.",
                                      @"Explanatory text on open panel when importing a game state.");
    panel.allowedFileTypes = @[BXGameStateType];
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    
    [panel beginSheetModalForWindow: self.windowForSheet completionHandler: ^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton)
        {
            NSURL *sourceURL = panel.URL;
            NSError *importError = nil;
            BOOL imported = [self importGameStateFromURL: sourceURL error: &importError];
            
            //Once importing is complete, restart the app to complete the operation.
            if (imported)
            {
                [self restartShowingLaunchPanel: NO];
            }
            //Otherwise, tell the user what went wrong.
            else
            {
                //In order to display the error to the user,
                //we need to get the open panel out of the way.
                [self.windowForSheet.attachedSheet orderOut: self];
                
                [self presentError: importError
                    modalForWindow: self.windowForSheet
                          delegate: self
                didPresentSelector: NULL
                       contextInfo: NULL];
            }
        }
    }];
}

- (IBAction) exportGameState: (id)sender
{
    //Don't continue if we have nothing to export
    if (!self.hasShadowedChanges)
        return;

    //Work out a suitable filename, based on the game name and the current date.
    NSString *nameFormat = NSLocalizedString(@"%1$@ %2$@", @"The filename format under which to save exported game states. %1$@ is the name of the current game. %2$@ is the current date and time.");
    
    NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName: @"BXScreenshotDateTransformer"];
    NSString *formattedDate = [transformer transformedValue: [NSDate date]];
    
    NSString *baseName  = [NSString stringWithFormat: nameFormat, self.displayName, formattedDate];
    //Sanitise the filename in case it contains characters that are disallowed for file paths.
    //TODO: move this off to an NSFileManager/NSString category.
    baseName = [baseName stringByReplacingOccurrencesOfString: @":" withString: @"-"];
    baseName = [baseName stringByReplacingOccurrencesOfString: @"/" withString: @"-"];
    
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.title = NSLocalizedString(@"Export game data",
                                    @"Title for save panel when exporting the current game state");
    panel.prompt = NSLocalizedString(@"Export",
                                     @"Label for confirmation button on save panel when exporting the current game state.");
    panel.nameFieldLabel = NSLocalizedString(@"Export as:",
                                             @"Label for filename field on save panel when exporting the current game state.");
    
    panel.allowedFileTypes = @[BXGameStateType];
    panel.nameFieldStringValue = baseName;
    panel.canSelectHiddenExtension = NO;
    
    [panel beginSheetModalForWindow: self.windowForSheet completionHandler: ^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton)
        {
            NSError *exportError = nil;
            NSURL *destinationURL = panel.URL;
            BOOL exported = [self exportGameStateToURL: destinationURL error: &exportError];
            if (exported)
            {
                [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs: @[destinationURL]];
            }
            else if (exportError)
            {
                [self.windowForSheet.attachedSheet orderOut: self];
                
                [self presentError: exportError
                    modalForWindow: self.windowForSheet
                          delegate: nil
                didPresentSelector: NULL
                       contextInfo: NULL];
            }
        }
    }];
}

- (void) _didPresentShadowOperationErrorWithRecovery: (BOOL)didRecover
                                         contextInfo: (void *)contextInfo
{
    [self restartShowingLaunchPanel: NO];
}


- (IBAction) mountNextDrivesInQueues: (id)sender
{
    [self _mountQueuedSiblingsAtOffset: 1];
}

- (IBAction) mountPreviousDrivesInQueues: (id)sender
{
    [self _mountQueuedSiblingsAtOffset: -1];
}

@end
