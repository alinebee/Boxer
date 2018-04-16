/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXBaseAppControllerPrivate.h"
#import "BXKeyboardEventTap.h"
#import "BXSession+BXUIControls.h"
#import "SystemPreferences.h"
#import "ADBAppKitVersionHelpers.h"

//For various keycode definitions
#import <IOKit/hidsystem/ev_keymap.h>
#import <Carbon/Carbon.h>

//Elements of this implementation were adapted from
//http://joshua.nozzi.name/2010/10/catching-media-key-events/


/// The event subtype for media key events, used to distinguish them from other kinds
/// of private system events.
#define BXMediaKeyEventSubtype 8

@implementation BXBaseAppController (BXHotKeys)

#pragma mark - Media key handling

+ (NSUInteger) _mediaKeyCode: (NSEvent *)theEvent
{
    return ((NSUInteger)theEvent.data1 & 0xFFFF0000) >> 16;
}

+ (BOOL) _mediaKeyDown: (NSEvent *)theEvent
{
    NSUInteger flags    = theEvent.data1 & 0x0000FFFF;
    BOOL isDown         = ((flags & 0xFF00) >> 8) == 0xA;
    
    return isDown;
}

- (void) mediaKeyPressed: (NSEvent *)theEvent
{   
    //Only respond to media keys if we have an active session, if we're active ourselves,
    //and if we can be sure other applications (like iTunes) won't also respond to them.
    if (![NSApp isActive] || !self.currentSession || self.hotkeySuppressionTap.status == BXKeyboardEventTapNotTapping)
        return;
    
    //Decipher information from the event and decide what to do with the key.
    NSUInteger keyCode  = [self.class _mediaKeyCode: theEvent];
    BOOL isPressed      = [self.class _mediaKeyDown: theEvent];
    
    switch (keyCode)
    {
        case NX_KEYTYPE_PLAY:
            if (isPressed)
                [self.currentSession togglePaused: self];
            break;
            
        case NX_KEYTYPE_FAST:
            if (isPressed)
                [self.currentSession fastForward: self];
            else
                [self.currentSession releaseFastForward: self];
            break;

        case NX_KEYTYPE_REWIND:
        default:
            break;
    }
}

- (BOOL) eventTap: (BXKeyboardEventTap *)tap shouldCaptureKeyEvent: (NSEvent *)event
{
    //Don't capture any keys when we're not the active application
    if (![NSApp isActive]) return NO;
    
    //Tweak: let Cmd-modified keys fall through, so that key-repeat events
    //for key equivalents are handled properly.
    if ((event.modifierFlags & NSCommandKeyMask) == NSCommandKeyMask)
        return NO;
    
    //Only capture if the current session is key and is running a program.
    if (!self.currentSession.programIsActive) return NO;
    if ([self documentForWindow: [NSApp keyWindow]] != self.currentSession) return NO;
    
    switch (event.keyCode)
    {
        case kVK_UpArrow:
        case kVK_DownArrow:
        case kVK_LeftArrow:
        case kVK_RightArrow:
        case kVK_F1:
        case kVK_F2:
        case kVK_F3:
        case kVK_F4:
        case kVK_F5:
        case kVK_F6:
        case kVK_F7:
        case kVK_F8:
        case kVK_F9:
        case kVK_F10:
        case kVK_F11:
        case kVK_F12:
            return YES;
            break;
        default:
            return NO;
    }
}

- (BOOL) eventTap: (BXKeyboardEventTap *)tap shouldCaptureSystemDefinedEvent: (NSEvent *)event
{
    //Ignore all events other than media keys.
    if (event.subtype != BXMediaKeyEventSubtype) return NO;
    
    //Don't capture any keys when we're not the active application.
    if (![NSApp isActive]) return NO;
    
    //Only capture media keys if the current session is running.
    if (!self.currentSession) return NO;
    @synchronized(self.currentSession)
    {
        if (!self.currentSession.isEmulating) return NO;
    }
    
    //Only listen for certain media keys.
    NSUInteger keyCode = [self.class _mediaKeyCode: event];
    
    switch (keyCode)
    {
        case NX_KEYTYPE_PLAY:
        case NX_KEYTYPE_FAST:
            return YES;
            break;
            
        case NX_KEYTYPE_REWIND:
        default:
            return NO;
            break;
    }
}


#pragma mark - Hotkey capture lifecycle

- (void) prepareHotkeyTap
{
    //Set up our keyboard event tap
    self.hotkeySuppressionTap = [[BXKeyboardEventTap alloc] init];
    self.hotkeySuppressionTap.delegate = self;
    
    //When we first set up the tap at application startup, check if Boxer already has permission to capture hotkeys.
    //We use this later to determine whether Boxer has been granted that permission while it's running,
    //and hence whether we may need to restart in order for those permissions to take effect.
    _couldCaptureHotkeysAtStartup = self.canCaptureHotkeys;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    //Event-tap threading is a hidden preference, so don't bother binding it.
    self.hotkeySuppressionTap.usesDedicatedThread = [defaults boolForKey: @"useMultithreadedEventTap"];
    
    [self.hotkeySuppressionTap bind: @"enabled"
                           toObject: defaults
                        withKeyPath: @"suppressSystemHotkeys"
                            options: nil];
}

- (void) checkHotkeyCaptureAvailability
{
    //Flag that hotkey capture permissions may have been granted while Boxer was inactive.
    [self willChangeValueForKey: @"canCaptureHotkeys"];
    [self didChangeValueForKey: @"canCaptureHotkeys"];
    
    if (self.canCaptureHotkeys)
    {
        //If our event tap isn't working at full strength yet, try to reattach it
        //to take advantage of broader hotkey permissions. We check if this was successful
        //below in eventTapDidFinishAttaching:.
        if (self.hotkeySuppressionTap.status != BXKeyboardEventTapTappingAllKeyboardEvents)
        {
            [self.hotkeySuppressionTap refreshEventTap];
        }
        
        //Otherwise, get rid of any hotkey alert we're displaying to the user,
        //since once we have hotkey capture permission there's nothing more they
        //can do with that alert.
        //(If we're trying to reattach the tap then we shouldn't close the modal alert
        //yet though, because we don't want to let the application resume *until* we know
        //if we need to restart the whole durn app. And we won't know that until downstairs
        //in eventTapDidFinishAttaching:.)
        else if (self.activeHotkeyAlert)
        {
            [NSApp abortModal];
        }
    }
}

- (BOOL) canCaptureHotkeys
{
    return [BXKeyboardEventTap canCaptureKeyEvents];
}

- (void) eventTapDidFinishAttaching: (BXKeyboardEventTap *)tap
{
    //Ensure we respond on the main thread, since this may be called from the tap's dedicated thread.
    dispatch_async(dispatch_get_main_queue(), ^{
        //If we have permission to capture hotkeys, dismiss any hotkey warning we were still displaying.
        //(See note above under checkHotkeyCaptureAvailability for why we do this here also.)
        if (self.canCaptureHotkeys && self.activeHotkeyAlert)
        {
            [NSApp abortModal];
        }
        
        //If the tap couldn't capture, even though we ought to have permission to tap, it probably means
        //we need to restart the application for those permissions to take effect.
        //TWEAK: we only flag ourselves as needing a restart if the permissions got toggled *during this
        //application session*. We don't want to restart - or advise the user to restart - if we already
        //had those permissions when we started and it didn't do us any good.
        //This is defensive coding in case a later OS X update prevents Boxer from establishing an event
        //tap at all even though the API reports that we have permission to do so (which would otherwise
        //cause us to enter a continual restart loop as we keep thinking we're just a restart away from
        //those permissions taking effect.)
		BOOL permissionGrantedThisSession = self.canCaptureHotkeys && !self->_couldCaptureHotkeysAtStartup;
        
        self.needsRestartForHotkeyCapture = (tap.status != BXKeyboardEventTapTappingAllKeyboardEvents) && permissionGrantedThisSession;
        
        //If the tap needs an application restart before it can provide full tapping capability,
        //and if we're not in the middle of running a game right now, then relaunch immediately.
        if (self.needsRestartForHotkeyCapture && (self.currentSession == nil || [self.currentSession canCloseSafely]))
        {
            [self relaunch: self];
        }
    });
}


#pragma mark - Hotkey capture availability warnings

+ (BOOL) hasPerAppAccessibilityControls
{
    //IMPLEMENTATION NOTE: a tidier way of doing this would be to check for the existence
    //of the AXIsProcessTrustedWithOptions() function, which was introduced in 10.9. However,
    //referencing that function at all would require the 10.9 SDK, which would prevent people
    //compiling Boxer on older OS X versions.
    return isRunningOnMavericksOrAbove();
}

+ (NSURL *) _accessibilityPreferencesURL
{
    NSURL *libraryURL = [[[NSFileManager defaultManager] URLsForDirectory: NSLibraryDirectory inDomains:NSSystemDomainMask] objectAtIndex: 0];
    NSURL *prefsURL = [libraryURL URLByAppendingPathComponent: @"PreferencePanes/UniversalAccessPref.prefPane"];
    
    return prefsURL;
}

+ (NSURL *) _securityPreferencesURL
{
    NSURL *libraryURL = [[[NSFileManager defaultManager] URLsForDirectory: NSLibraryDirectory inDomains:NSSystemDomainMask] objectAtIndex: 0];
    NSURL *prefsURL = [libraryURL URLByAppendingPathComponent: @"PreferencePanes/Security.prefPane"];
    
    return prefsURL;
}

+ (NSString *) localizedSystemAccessibilityPreferencesName
{
    NSURL *prefsURL = [self hasPerAppAccessibilityControls] ? self._securityPreferencesURL : self._accessibilityPreferencesURL;
    
    NSBundle *prefs = [NSBundle bundleWithURL: prefsURL];
    NSString *prefsName = [prefs objectForInfoDictionaryKey: @"CFBundleName"];
    
    return prefsName;
}

- (IBAction) showHotkeyWarningIfUnavailable: (id)sender
{
    if (self.shouldShowHotkeyWarning)
    {
        NSAlert *hotkeyWarning = [self hotkeyWarningAlert];
        
        self.activeHotkeyAlert = hotkeyWarning;
        NSInteger returnCode = [hotkeyWarning runModal];
        self.activeHotkeyAlert = nil;
        
        if (returnCode == NSAlertFirstButtonReturn) //Show accessibility preferences button
        {
            //NOTE: this if branch will not normally be triggered, because the relevant alert button
            //will have been rewired to trigger the action directly without ending the alert.
            [self showSystemAccessibilityControls: self];
        }
        else if (returnCode == NSAlertSecondButtonReturn) //Skip button
        {
            self.hotkeyWarningSuppressed = YES;
        }
    }
}

- (BOOL) shouldShowHotkeyWarning
{
    if (self.canCaptureHotkeys)
        return NO;
    
    BOOL showHotkeyWarning = [[NSUserDefaults standardUserDefaults] boolForKey: @"showHotkeyWarning"];
    if (showHotkeyWarning == NO)
        return NO;
    
    if (self.hotkeyWarningSuppressed)
        return NO;
    
    return YES;
}

- (BOOL) hotkeyWarningSuppressed
{
    NSString *suppressionKey = ([self.class hasPerAppAccessibilityControls]) ? @"hasDismissedPerAppHotkeyWarning" : @"hasDismissedHotkeyWarning";
    return [[NSUserDefaults standardUserDefaults] boolForKey: suppressionKey];
}

- (void) setHotkeyWarningSuppressed: (BOOL)suppress
{
    NSString *suppressionKey = ([self.class hasPerAppAccessibilityControls]) ? @"hasDismissedPerAppHotkeyWarning" : @"hasDismissedHotkeyWarning";
    [[NSUserDefaults standardUserDefaults] setBool: suppress forKey: suppressionKey];
}

- (NSAlert *) hotkeyWarningAlert
{
    NSAlert *hotkeyWarning = [[NSAlert alloc] init];
    
    NSString *appName = [self.class appName];
    NSString *prefsName = [self.class localizedSystemAccessibilityPreferencesName];
    
    if ([self.class hasPerAppAccessibilityControls])
    {
        NSString *messageFormat = NSLocalizedString(@"For the best experience, %1$@ needs accessibility control in OS X’s %2$@ preferences.",
                                                    @"Bold text of alert shown if the application is not yet trusted for accessibility access on 10.9 and above. %1$@ is the name of the application; %2$@ is the localized title of the Security & Privacy preferences pane.");
        
        hotkeyWarning.messageText = [NSString stringWithFormat: messageFormat, appName, prefsName];
    }
    else
    {
        NSString *messageFormat = NSLocalizedString(@"For the best experience, turn on “Enable access for assistive devices” in OS X’s %1$@ preferences.",
                                          @"Bold text of alert shown if the user does not have 'Allow access for assistive devices' enabled in OS X 10.8 and below. %1$@ is the localized name of the Accessibility preferences pane.");
        
        hotkeyWarning.messageText = [NSString stringWithFormat: messageFormat, prefsName];
    }
    
    NSString *informativeTextFormat = NSLocalizedString(@"This ensures that OS X hotkeys won’t interfere with %1$@’s game controls.",
                                                        @"Informative text of alert shown if the application is not yet trusted for accessibility access on 10.9 and above. %1$@ is the name of the application.");
    
    hotkeyWarning.informativeText = [NSString stringWithFormat: informativeTextFormat, appName];
    
    NSString *openPrefsButtonFormat = NSLocalizedString(@"Open %@ Preferences", @"Label of default button in hotkey warning alert. %@ is the localized name of the preferences pane that contains the relevant accessibility controls.");
    
    NSString *openPrefsButtonLabel = [NSString stringWithFormat: openPrefsButtonFormat, prefsName];
    NSString *skipLabel = NSLocalizedString(@"Skip", @"Label of button in hotkey warning alert to dismiss the alert without showing accessibility preferences.");
    
    NSButton *openPrefsButton = [hotkeyWarning addButtonWithTitle: openPrefsButtonLabel];
    //IMPLEMENTATION NOTE: we rewire the button so that it will show the preferences without dismissing the alert.
    openPrefsButton.target = self;
    openPrefsButton.action = @selector(showSystemAccessibilityControls:);
    
    
    NSButton *skipButton = [hotkeyWarning addButtonWithTitle: skipLabel];
    skipButton.keyEquivalent = @"\e";
    
    hotkeyWarning.delegate = self;
    hotkeyWarning.showsHelp = YES;
    hotkeyWarning.helpAnchor = @"spaces-shortcuts";
    
    return hotkeyWarning;
}


- (IBAction) showSystemAccessibilityControls: (id)sender
{
    if ([self.class hasPerAppAccessibilityControls])
        [self _showPerAppAccessibilityControls];
    else
        [self _showLegacyAccessibilityControls];
}

- (void) _showLegacyAccessibilityControls
{
    [[NSWorkspace sharedWorkspace] openURL: [self.class _accessibilityPreferencesURL]];
}

- (void) _showPerAppAccessibilityControls
{
    //Get a reference we can use to send scripting messages to the System Preferences application.
    //This will not launch the application or establish a connection to it until we start sending it commands.
    SystemPreferencesApplication *prefsApp = [SBApplication applicationWithBundleIdentifier: @"com.apple.systempreferences"];
    
    //Tell the scripting bridge wrapper not to block this thread while waiting for replies from the other process.
    //(The commands we'll be sending it don't have return values that we care about.)
    prefsApp.sendMode = kAENoReply;
    
    //Get a reference to the accessibility anchor within the Security & Privacy pane.
    //Note that even if the pane or the anchor don't exist (e.g. they've been renamed in a later OS X version),
    //we'll still get objects for them: but any attempts to talk to those objects will silently fail.
    SystemPreferencesPane *securityPane = [prefsApp.panes objectWithID: @"com.apple.preference.security"];
    SystemPreferencesAnchor *accessibilityAnchor = [securityPane.anchors objectWithName: @"Privacy_Accessibility"];
    
    //Open the System Preferences application and bring its window to the foreground.
    [prefsApp activate];
    
    //Show the accessibility settings, if they exist.
    [accessibilityAnchor reveal];
}

@end
