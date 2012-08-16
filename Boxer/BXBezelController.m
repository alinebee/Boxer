/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXBezelController.h"
#import "BXBaseAppController.h"
#import "NSWindow+BXWindowEffects.h"
#import "BXSession+BXEmulatorControls.h"
#import "BXDOSWindow.h"
#import "BXDOSWindowController.h"
#import "BXGeometry.h"
#import "BXDrive.h"
#import "BXGamebox.h"
#import "BXValueTransformers.h"
#import "BXInspectorController.h"
#import "NSString+BXStringFormatting.h"
#import "BXHIDMonitor.h"
#import "BXPostLeopardAPIs.h"


#define BXBezelFadeDuration 0.25

#define BXScreenshotBezelDuration 0.75
#define BXVolumeBezelDuration 0.75
#define BXPausePlayBezelDuration 0.75
#define BXFastForwardBezelDuration 0.0 //Leave on-screen until dismissed
#define BXNumpadBezelDuration 2.0
#define BXNumlockBezelDuration 2.0
#define BXFullscreenBezelDuration 3.0
#define BXJoystickIgnoredBezelDuration 3.0
#define BXDriveBezelDuration 2.0
#define BXCPUBezelDuration 0.75
#define BXThrottleBezelDuration 0.75
#define BXMT32MessageBezelDuration 4.0
#define BXMT32MissingBezelDuration 3.0


@implementation BXBezelController
@synthesize driveAddedBezel, driveSwappedBezel, driveRemovedBezel, driveImportedBezel;
@synthesize pauseBezel, playBezel, fastForwardBezel, fullscreenBezel, screenshotBezel;
@synthesize joystickIgnoredBezel, CPUSpeedBezel, throttleBezel, volumeBezel;
@synthesize MT32MessageBezel, MT32MissingBezel;
@synthesize numpadActiveBezel, numpadInactiveBezel;
@synthesize numlockActiveBezel, numlockInactiveBezel;


+ (NSImage *) bezelIconForDrive: (BXDrive *)drive
{
    NSString *iconName;
    switch (drive.type)
    {
        case BXDriveCDROM:
            iconName = @"CDROMTemplate";
            break;
        case BXDriveFloppyDisk:
            iconName = @"DisketteTemplate";
            break;
        default:
            iconName = @"HardDiskTemplate";
    }
    
    return [NSImage imageNamed: iconName];
}

+ (id) controller
{
	static id singleton = nil;
    
	if (!singleton)
    {
        singleton = [[self alloc] initWithWindowNibName: @"Bezel"];
        //Force the instance to initialise its window early,
        //so that its window and all its views are available for use.
        [singleton window];
    }
	return singleton;
}

- (void) dealloc
{
    self.driveAddedBezel = nil;
    self.driveSwappedBezel = nil;
    self.driveRemovedBezel = nil;
    self.driveImportedBezel = nil;
    self.fullscreenBezel = nil;
    self.pauseBezel = nil;
    self.playBezel = nil;
    self.fastForwardBezel = nil;
    self.CPUSpeedBezel = nil;
    self.throttleBezel = nil;
    self.volumeBezel = nil;
    self.joystickIgnoredBezel = nil;
    self.MT32MessageBezel = nil;
    self.MT32MissingBezel = nil;
    self.numpadActiveBezel = nil;
    self.numpadInactiveBezel = nil;
    self.numlockActiveBezel = nil;
    self.numlockInactiveBezel = nil;
    
    [super dealloc];
}

- (NSView *) currentBezel
{
    return [self.window.contentView subviews].lastObject;
}

- (void) loadWindow
{
    //Load our views from the NIB as usual
    [super loadWindow];
    
    //Create our own window, as one is not defined in the NIB.
    //(we need a borderless transparent window, which XCode can't define in a NIB file.)
    NSWindow *bezelWindow = [[NSWindow alloc] initWithContentRect: NSZeroRect
                                                        styleMask: NSBorderlessWindowMask
                                                          backing: NSBackingStoreBuffered
                                                            defer: YES];
    
    bezelWindow.backgroundColor = [NSColor clearColor];
    [bezelWindow setOpaque: NO];
    bezelWindow.ignoresMouseEvents = YES;
    bezelWindow.hidesOnDeactivate = YES;
    bezelWindow.level = NSPopUpMenuWindowLevel;
    bezelWindow.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
    
    self.window = [bezelWindow autorelease];
}

- (void) showBezel: (NSView *)bezel
       forDuration: (NSTimeInterval)duration
          priority: (BXBezelPriority)priority
{   
    //Only display the new bezel if it's of equal or higher priority
    //than the one we’re currently displaying
    if (priority >= currentPriority)
    {
        currentPriority = priority;
        
        //Swap the old bezel for the new one, and resize the bezel window to fit it
        if (bezel != [self currentBezel])
        {
            [self.currentBezel removeFromSuperviewWithoutNeedingDisplay];
            [self.window setContentSize: bezel.frame.size];
            [self.window.contentView addSubview: bezel];
            
            [self centerBezel];
        }
        
        //Fade in the bezel window if it isn't already visible
        [self.window fadeInWithDuration: BXBezelFadeDuration];
        
        //Start counting down to hiding the bezel again
        [NSObject cancelPreviousPerformRequestsWithTarget: self
                                                 selector: @selector(hideBezel)
                                                   object: nil];
        
        if (duration > 0)
        {
            [self performSelector: @selector(hideBezel)
                       withObject: nil
                       afterDelay: duration];
        }
    }
}

- (void) hideBezel
{
    currentPriority = BXBezelPriorityLow;
    [[self window] fadeOutWithDuration: BXBezelFadeDuration];
}

- (void) centerBezel
{
    //Position the bezel so that it's centered in the bottom third of the available screen area
    NSRect screenFrame = [NSScreen mainScreen].visibleFrame;
    NSRect windowFrame = self.window.frame;
    
    NSRect centeredFrame = alignInRectWithAnchor(windowFrame, screenFrame, NSMakePoint(0.5f, 0.25f));
    
    [self.window setFrameOrigin: centeredFrame.origin];
}


#pragma mark -
#pragma mark Bezel-specific display methods

- (void) showScreenshotBezel
{
    [self showBezel: self.screenshotBezel
        forDuration: BXScreenshotBezelDuration
           priority: BXBezelPriorityLow];
}


- (void) showPauseBezel
{
    [self showBezel: self.pauseBezel
        forDuration: BXPausePlayBezelDuration
           priority: BXBezelPriorityHigh];
}

- (void) showPlayBezel
{
    [self showBezel: self.playBezel
        forDuration: BXPausePlayBezelDuration
           priority: BXBezelPriorityHigh];    
}

- (void) showFastForwardBezel
{
    [self showBezel: self.fastForwardBezel
        forDuration: BXFastForwardBezelDuration
           priority: BXBezelPriorityHigh];
}

- (void) showNumpadActiveBezel
{
    [self showBezel: self.numpadActiveBezel
        forDuration: BXNumpadBezelDuration
           priority: BXBezelPriorityNormal];
}

- (void) showNumpadInactiveBezel
{
    [self showBezel: self.numpadInactiveBezel
        forDuration: BXNumpadBezelDuration
           priority: BXBezelPriorityNormal];    
}

- (void) showNumlockActiveBezel
{
    [self showBezel: self.numlockActiveBezel
        forDuration: BXNumlockBezelDuration
           priority: BXBezelPriorityNormal];
}

- (void) showNumlockInactiveBezel
{
    [self showBezel: self.numlockInactiveBezel
        forDuration: BXNumlockBezelDuration
           priority: BXBezelPriorityNormal];    
}

- (void) showFullscreenBezel
{
    BXSession *currentSession = [[NSApp delegate] currentSession];
    BOOL isInDOSView = (currentSession.DOSWindowController.currentPanel == BXDOSWindowDOSView);
    BOOL fullscreenMessageEnabled = [[NSUserDefaults standardUserDefaults] boolForKey: @"showFullscreenToggleMessage"];
    if (fullscreenMessageEnabled && isInDOSView)
    {
        [self showBezel: self.fullscreenBezel
            forDuration: BXFullscreenBezelDuration
               priority: BXBezelPriorityNormal];
    }
}

- (void) showJoystickIgnoredBezel
{
    [self showBezel: self.joystickIgnoredBezel
        forDuration: BXJoystickIgnoredBezelDuration
           priority: BXBezelPriorityLow];
}

- (void) showCPUSpeedBezelForSpeed: (NSInteger)cpuSpeed
{
    //Tweak: if the CPU inspector panel is visible, don’t bother showing the bezel.
    BXInspectorController *inspector = [NSClassFromString(@"BXInspectorController") controller];
    if (inspector.panelShown && inspector.selectedTabViewItemIndex == BXCPUInspectorPanelTag)
        return;
    
    NSView *bezel = self.CPUSpeedBezel;
    
    NSString *speedDescription = [BXSession descriptionForSpeed: cpuSpeed];
    
    NSLevelIndicator *level = [bezel viewWithTag: BXBezelLevel];
    NSTextField *label      = [bezel viewWithTag: BXBezelLevelStatus];
    
    //Make maximum (auto) values appear at the end of the speed scale
    NSInteger displayedSpeed = (cpuSpeed == BXAutoSpeed) ? BXMaxSpeedThreshold : cpuSpeed;
       
    //TODO: set these up with a binding instead?
    NSValueTransformer *cpuScale = [NSValueTransformer valueTransformerForName: @"BXSpeedSliderTransformer"];
    
    NSNumber *scaledValue = [cpuScale transformedValue: [NSNumber numberWithInteger: displayedSpeed]];
                             
    level.doubleValue = scaledValue.doubleValue;
    label.stringValue = speedDescription;
    
    [self showBezel: bezel
        forDuration: BXCPUBezelDuration
           priority: BXBezelPriorityNormal];
}

- (void) showThrottleBezelForValue: (float)throttleValue
{
    NSView *bezel = self.throttleBezel;
    
    NSString *format = NSLocalizedString(@"%u%% throttle", @"Label for flightstick throttle-adjusted bezel notification. %u is the current throttle value expressed as a percentage from 0 to 100%.");
    
    //The throttle is expressed as a value from 1.0 (min) to -1.0 (max):
    //Convert it to a percentage from 0-100.
    NSUInteger percentage = 50 * (1.0f - throttleValue);
    NSString *throttleDescription = [NSString stringWithFormat: format, percentage];
    
    NSLevelIndicator *level = [bezel viewWithTag: BXBezelLevel];
    NSTextField *label      = [bezel viewWithTag: BXBezelLevelStatus];
    
    level.integerValue = percentage;
    label.stringValue = throttleDescription;
    
    [self showBezel: bezel
        forDuration: BXThrottleBezelDuration
           priority: BXBezelPriorityNormal];
}

- (void) showVolumeBezelForVolume: (float)volume
{
    if (!self.shouldShowVolumeNotifications) return;
    
    NSView *bezel = self.volumeBezel;
    
    NSLevelIndicator *level = [bezel viewWithTag: BXBezelLevel];
    NSImageView *icon = [bezel viewWithTag: BXBezelIcon];
    
    level.floatValue = volume;
    
    NSString *iconName;
    if      (volume > 0.66f)
        iconName = @"Volume100PercentTemplate";
    else if (volume > 0.33f)
        iconName = @"Volume66PercentTemplate";
    else if (volume > 0.0f)
        iconName = @"Volume33PercentTemplate";
    else
        iconName = @"Volume0PercentTemplate";
    
    icon.image = [NSImage imageNamed: iconName];
    
    [self showBezel: bezel
        forDuration: BXVolumeBezelDuration
           priority: BXBezelPriorityNormal];
}

- (void) showMT32BezelForMessage: (NSString *)message
{
    //Suppress MT-32 messages if the relevant user-defaults option is disabled.
    if (![[NSUserDefaults standardUserDefaults] boolForKey: @"showMT32LCDMessages"]) return;
    
    NSView *bezel = self.MT32MessageBezel;
    
    NSTextField *messageField = [bezel viewWithTag: BXBezelMessage];
    
    messageField.stringValue = message;
    
    [self showBezel: bezel
        forDuration: BXMT32MessageBezelDuration
           priority: BXBezelPriorityHigh];
}

- (void) showMT32MissingBezel
{
    //Don't show the missing MT-32 bezel if we're a standalone game app,
    //as there's nothing the user can do about it.
    if ([[NSApp delegate] isStandaloneGameBundle])
        return;
    
    [self showBezel: self.MT32MissingBezel
        forDuration: BXMT32MissingBezelDuration
           priority: BXBezelPriorityLow];
}


- (BOOL) shouldShowDriveNotifications
{
    //Suppress drive notifications while the Drive Inspector panel is open.
    
    BXInspectorController *inspector = [NSClassFromString(@"BXInspectorController") controller];
    return !(inspector.panelShown && inspector.selectedTabViewItemIndex == BXDriveInspectorPanelTag);
}

- (BOOL) shouldShowVolumeNotifications
{
    //Suppress volume notifications while the window's own volume indicator is visible.
    BXDOSWindowController *windowController = [[NSApp delegate] currentSession].DOSWindowController;
    return !windowController.statusBarShown || windowController.window.isFullScreen;
}

- (void) showDriveAddedBezelForDrive: (BXDrive *)drive
{
    if (![self shouldShowDriveNotifications]) return;
    
    NSView *bezel               = self.driveAddedBezel;
    NSImageView *icon           = [bezel viewWithTag: BXBezelIcon];
    NSTextField *actionLabel    = [bezel viewWithTag: BXBezelDriveAction];
    NSTextField *titleLabel     = [bezel viewWithTag: BXBezelDriveTitle];
    
    NSString *actionFormat = NSLocalizedString(@"Drive %1$@ added",
                                               @"Label for drive-added bezel notification. %1$@ is the drive letter.");
    
    actionLabel.stringValue = [NSString stringWithFormat: actionFormat, drive.letter];
    titleLabel.stringValue = drive.title;
    icon.image = [self.class bezelIconForDrive: drive];
    
    [self showBezel: bezel
        forDuration: BXDriveBezelDuration
           priority: BXBezelPriorityNormal];
}

- (void) showDriveSwappedBezelFromDrive: (BXDrive *)fromDrive toDrive: (BXDrive *)toDrive
{
    if (![self shouldShowDriveNotifications]) return;
    
    NSView *bezel               = self.driveSwappedBezel;
    NSImageView *fromIcon       = [bezel viewWithTag: BXBezelDriveFromIcon];
    NSImageView *toIcon         = [bezel viewWithTag: BXBezelDriveToIcon];
    NSTextField *actionLabel    = [bezel viewWithTag: BXBezelDriveAction];
    NSTextField *titleLabel     = [bezel viewWithTag: BXBezelDriveTitle];
    
    NSString *actionFormat = NSLocalizedString(@"Drive %1$@ swapped", @"Label for drive-swapped bezel notification. %1$@ is the drive letter.");
    
    actionLabel.stringValue = [NSString stringWithFormat: actionFormat, toDrive.letter];
    titleLabel.stringValue = toDrive.title;
    
    fromIcon.image = [self.class bezelIconForDrive: fromDrive];
    toIcon.image = [self.class bezelIconForDrive: toDrive];
    
    [self showBezel: bezel
        forDuration: BXDriveBezelDuration
           priority: BXBezelPriorityNormal];
}

- (void) showDriveRemovedBezelForDrive: (BXDrive *)drive
{
    if (![self shouldShowDriveNotifications]) return;
    
    NSView *bezel               = self.driveRemovedBezel;
    NSImageView *icon           = [bezel viewWithTag: BXBezelIcon];
    NSTextField *actionLabel    = [bezel viewWithTag: BXBezelDriveAction];
    NSTextField *titleLabel     = [bezel viewWithTag: BXBezelDriveTitle];

    NSString *actionFormat = NSLocalizedString(@"Drive %1$@ ejected", @"Label for drive-removed bezel notification. %1$@ is the drive letter.");
    
    actionLabel.stringValue = [NSString stringWithFormat: actionFormat, drive.letter];
    titleLabel.stringValue = drive.title;
    icon.image = [NSImage imageNamed: @"EjectTemplate"];
    
    [self showBezel: bezel
        forDuration: BXDriveBezelDuration
           priority: BXBezelPriorityNormal];
}

- (void) showDriveImportedBezelForDrive: (BXDrive *)drive
                              toGamebox: (BXGamebox *)gamebox
{
    if (![self shouldShowDriveNotifications]) return;
    
    NSView *bezel               = self.driveImportedBezel;
    NSImageView *icon           = [bezel viewWithTag: BXBezelIcon];
    NSTextField *actionLabel    = [bezel viewWithTag: BXBezelDriveAction];
    NSTextField *titleLabel     = [bezel viewWithTag: BXBezelDriveTitle];
    
    NSString *actionFormat = NSLocalizedString(@"Drive %2$@ imported", @"Label for drive-imported bezel notification. %1$@ is the drive letter.");
    
    actionLabel.stringValue = [NSString stringWithFormat: actionFormat, drive.letter];
    titleLabel.stringValue = drive.title;
    icon.image = [self.class bezelIconForDrive: drive];
    
    [self showBezel: bezel
        forDuration: BXDriveBezelDuration
           priority: BXBezelPriorityNormal];
}

@end
