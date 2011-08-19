/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXBezelController.h"
#import "NSWindow+BXWindowEffects.h"
#import "BXSession+BXEmulatorControls.h"
#import "BXGeometry.h"
#import "BXDrive.h"
#import "BXPackage.h"
#import "BXValueTransformers.h"
#import "BXInspectorController.h"
#import "NSString+BXStringFormatting.h"
#import "BXHIDMonitor.h"
#import "BXPostLeopardAPIs.h"


#define BXBezelFadeDuration 0.25

#define BXPauseBezelDuration 1.0
#define BXFullscreenBezelDuration 3.0
#define BXJoystickIgnoredBezelDuration 3.0
#define BXDriveBezelDuration 3.0
#define BXCPUBezelDuration 0.75
#define BXThrottleBezelDuration 0.75


@implementation BXBezelController
@synthesize driveAddedBezel, driveSwappedBezel, driveRemovedBezel, driveImportedBezel;
@synthesize pauseBezel, playBezel, fullscreenBezel;
@synthesize joystickIgnoredBezel, CPUSpeedBezel, throttleBezel;

+ (NSImage *) bezelIconForDrive: (BXDrive *)drive
{
    NSString *iconName;
    switch ([drive type])
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
    [self setDriveAddedBezel: nil],         [driveAddedBezel release];
    [self setDriveSwappedBezel: nil],       [driveSwappedBezel release];
    [self setDriveRemovedBezel: nil],       [driveRemovedBezel release];
    [self setDriveImportedBezel: nil],      [driveImportedBezel release];
    [self setFullscreenBezel: nil],         [fullscreenBezel release];
    [self setPauseBezel: nil],              [pauseBezel release];
    [self setPlayBezel: nil],               [playBezel release];
    [self setCPUSpeedBezel: nil],           [CPUSpeedBezel release];
    [self setThrottleBezel: nil],           [throttleBezel release];
    [self setJoystickIgnoredBezel: nil],    [joystickIgnoredBezel release];
    
    [super dealloc];
}

- (NSView *) currentBezel
{
    return [[[[self window] contentView] subviews] lastObject];
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
    
    [bezelWindow setBackgroundColor: [NSColor clearColor]];
    [bezelWindow setOpaque: NO];
    [bezelWindow setIgnoresMouseEvents: YES];
    [bezelWindow setLevel: NSPopUpMenuWindowLevel];
    [bezelWindow setCollectionBehavior: NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary];
    
    [self setWindow: [bezelWindow autorelease]];
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
            [[self currentBezel] removeFromSuperviewWithoutNeedingDisplay];
            [[self window] setContentSize: [bezel frame].size];
            [[[self window] contentView] addSubview: bezel];
            
            [self centerBezel];
        }
        
        //Fade in the bezel window if it isn't already visible
        [[self window] fadeInWithDuration: BXBezelFadeDuration];
        
        //Start counting down to hiding the bezel again
        [NSObject cancelPreviousPerformRequestsWithTarget: self
                                                 selector: @selector(hideBezel)
                                                   object: nil];
        
        [self performSelector: @selector(hideBezel)
                   withObject: nil
                   afterDelay: duration];
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
    NSRect screenFrame = [[NSScreen mainScreen] visibleFrame];
    NSRect windowFrame = [[self window] frame];
    
    NSRect centeredFrame = alignInRectWithAnchor(windowFrame, screenFrame, NSMakePoint(0.5f, 0.25f));
    
    [[self window] setFrameOrigin: centeredFrame.origin];
}


#pragma mark -
#pragma mark Bezel-specific display methods

- (void) showPauseBezel
{
    [self showBezel: [self pauseBezel]
        forDuration: BXPauseBezelDuration
           priority: BXBezelPriorityHigh];
}

- (void) showPlayBezel
{
    [self showBezel: [self playBezel]
        forDuration: BXPauseBezelDuration
           priority: BXBezelPriorityHigh];    
}

- (void) showFullscreenBezel
{
    [self showBezel: [self fullscreenBezel]
        forDuration: BXFullscreenBezelDuration
           priority: BXBezelPriorityHigh];
}

- (void) showJoystickIgnoredBezel
{
    if (!([[self window] isVisible] && [[self currentBezel] isEqual: [self joystickIgnoredBezel]]))
    {
        //Check if there are any controller helpers running, which may
        //be remapping joystick input themselves.
        //If there are then don't warn the user, as the game is probably
        //receiving the input some other way.
        if ([[BXHIDMonitor runningHIDRemappers] count]) return;
    }
    
    [self showBezel: [self joystickIgnoredBezel]
        forDuration: BXJoystickIgnoredBezelDuration
           priority: BXBezelPriorityLow];
}

- (void) showCPUSpeedBezelForSpeed: (NSInteger)cpuSpeed
{
    //Tweak: if the CPU inspector panel is visible, don’t bother showing the bezel.
    BXInspectorController *inspector = [BXInspectorController controller];
    if ([inspector panelShown] && [inspector selectedTabViewItemIndex] == BXCPUInspectorPanelTag)
        return;
    
    NSView *bezel = [self CPUSpeedBezel];
    
    NSString *speedDescription = [BXSession descriptionForSpeed: cpuSpeed];
    
    NSLevelIndicator *level = [bezel viewWithTag: BXBezelLevel];
    NSTextField *label      = [bezel viewWithTag: BXBezelLevelStatus];
    
    //Make maximum (auto) values appear at the end of the speed scale
    NSInteger displayedSpeed = (cpuSpeed == BXAutoSpeed) ? BXMaxSpeedThreshold : cpuSpeed;
       
    //TODO: set these up with a binding instead?
    NSValueTransformer *cpuScale = [NSValueTransformer valueTransformerForName: @"BXSpeedSliderTransformer"];
    
    NSNumber *scaledValue = [cpuScale transformedValue: [NSNumber numberWithInteger: displayedSpeed]];
                             
    [level setDoubleValue: [scaledValue doubleValue]];
    [label setStringValue: speedDescription];
    
    [self showBezel: bezel
        forDuration: BXCPUBezelDuration
           priority: BXBezelPriorityNormal];
}

- (void) showThrottleBezelForValue: (float)throttleValue
{
    NSView *bezel = [self throttleBezel];
    
    NSString *format = NSLocalizedString(@"%u%% throttle", @"Label for flightstick throttle-adjusted bezel notification. %u is the current throttle value expressed as a percentage from 0 to 100%.");
    
    //The throttle is expressed as a value from 1.0 (min) to -1.0 (max):
    //Convert it to a percentage from 0-100.
    NSUInteger percentage = 50 * (1.0f - throttleValue);
    NSString *throttleDescription = [NSString stringWithFormat: format, percentage, nil];
    
    NSLevelIndicator *level = [bezel viewWithTag: BXBezelLevel];
    NSTextField *label      = [bezel viewWithTag: BXBezelLevelStatus];
    
    [level setIntegerValue: percentage];
    [label setStringValue: throttleDescription];
    
    [self showBezel: bezel
        forDuration: BXThrottleBezelDuration
           priority: BXBezelPriorityNormal];
}

- (BOOL) shouldShowDriveNotifications
{
    //Suppress drive notifications while the Drive Inspector panel is open.
    //Disabled for now; there's enough extra info provided by the bezels that
    //they aren't redundant to show while the inspector is open.
    
    //BXInspectorController *inspector = [BXInspectorController controller];
    //return !([inspector panelShown] && [inspector selectedTabViewItemIndex] == BXDriveInspectorPanelTag);

    return YES;
}

- (void) showDriveAddedBezelForDrive: (BXDrive *)drive
{
    if (![self shouldShowDriveNotifications]) return;
    
    NSView *bezel               = [self driveAddedBezel];
    NSImageView *icon           = [bezel viewWithTag: BXBezelIcon];
    NSTextField *actionLabel    = [bezel viewWithTag: BXBezelDriveAction];
    NSTextField *titleLabel     = [bezel viewWithTag: BXBezelDriveTitle];
    
    NSImage *iconImage = [[self class] bezelIconForDrive: drive];
    NSString *driveTitle = [drive title];
    
    NSString *actionFormat = NSLocalizedString(@"Drive %1$@ added", @"Label for drive-added bezel notification. %1$@ is the drive letter.");
    NSString *actionDescription = [NSString stringWithFormat: actionFormat, [drive letter], nil];
                             
    [icon setImage:                 iconImage];
    [actionLabel setStringValue:    actionDescription];
    [titleLabel setStringValue:     driveTitle];
    
    [self showBezel: bezel
        forDuration: BXDriveBezelDuration
           priority: BXBezelPriorityNormal];
}

- (void) showDriveSwappedBezelFromDrive: (BXDrive *)fromDrive toDrive: (BXDrive *)toDrive
{
    if (![self shouldShowDriveNotifications]) return;
    
    NSView *bezel               = [self driveSwappedBezel];
    NSImageView *fromIcon       = [bezel viewWithTag: BXBezelDriveFromIcon];
    NSImageView *toIcon         = [bezel viewWithTag: BXBezelDriveToIcon];
    NSTextField *actionLabel    = [bezel viewWithTag: BXBezelDriveAction];
    NSTextField *titleLabel     = [bezel viewWithTag: BXBezelDriveTitle];
    
    NSString *driveTitle    = [toDrive title];
    NSImage *fromIconImage  = [[self class] bezelIconForDrive: fromDrive];
    NSImage *toIconImage    = [[self class] bezelIconForDrive: toDrive];
    
    NSString *actionFormat = NSLocalizedString(@"Drive %1$@ swapped", @"Label for drive-swapped bezel notification. %1$@ is the drive letter.");
    NSString *actionDescription = [NSString stringWithFormat: actionFormat, [toDrive letter], nil];
        
    [fromIcon setImage:             fromIconImage];
    [toIcon setImage:               toIconImage];
    [actionLabel setStringValue:    actionDescription];
    [titleLabel setStringValue:     driveTitle];
    
    [self showBezel: bezel
        forDuration: BXDriveBezelDuration
           priority: BXBezelPriorityNormal];
}

- (void) showDriveRemovedBezelForDrive: (BXDrive *)drive
{
    if (![self shouldShowDriveNotifications]) return;
    
    NSView *bezel               = [self driveRemovedBezel];
    NSImageView *icon           = [bezel viewWithTag: BXBezelIcon];
    NSTextField *actionLabel    = [bezel viewWithTag: BXBezelDriveAction];
    NSTextField *titleLabel     = [bezel viewWithTag: BXBezelDriveTitle];

    NSImage *iconImage      = [NSImage imageNamed: @"EjectTemplate"];
    NSString *driveTitle    = [drive title];
    
    NSString *actionFormat = NSLocalizedString(@"Drive %1$@ ejected", @"Label for drive-removed bezel notification. %1$@ is the drive letter.");
    NSString *actionDescription = [NSString stringWithFormat: actionFormat, [drive letter], nil];
    
    
    [icon setImage:                 iconImage];
    [actionLabel setStringValue:    actionDescription];
    [titleLabel setStringValue:     driveTitle];
    
    [self showBezel: bezel
        forDuration: BXDriveBezelDuration
           priority: BXBezelPriorityNormal];
}

- (void) showDriveImportedBezelForDrive: (BXDrive *)drive
                              toPackage: (BXPackage *)package
{
    if (![self shouldShowDriveNotifications]) return;
    
    NSView *bezel               = [self driveImportedBezel];
    NSImageView *icon           = [bezel viewWithTag: BXBezelIcon];
    NSTextField *actionLabel    = [bezel viewWithTag: BXBezelDriveAction];
    NSTextField *titleLabel     = [bezel viewWithTag: BXBezelDriveTitle];
    
    NSImage *iconImage = [[self class] bezelIconForDrive: drive];
    NSString *driveTitle = [drive title];
    
    NSString *actionFormat = NSLocalizedString(@"Drive %2$@ imported", @"Label for drive-imported bezel notification. %1$@ is the drive letter.");
	NSString *actionDescription = [NSString stringWithFormat: actionFormat, [drive letter], nil];
    
    [icon setImage:                 iconImage];
    [actionLabel setStringValue:    actionDescription];
    [titleLabel setStringValue:     driveTitle];
    
    [self showBezel: bezel
        forDuration: BXDriveBezelDuration
           priority: BXBezelPriorityNormal];
}
@end
