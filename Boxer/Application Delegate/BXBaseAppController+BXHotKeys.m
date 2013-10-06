/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXBaseAppController+BXHotKeys.h"
#import "BXKeyboardEventTap.h"
#import "BXSession+BXUIControls.h"
#import "SystemPreferences.h"
#import "ADBAppKitVersionHelpers.h"

//For various keycode definitions
#import <IOKit/hidsystem/ev_keymap.h>
#import <Carbon/Carbon.h>

//Elements of this implementation were adapted from
//http://joshua.nozzi.name/2010/10/catching-media-key-events/

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
    if (![NSApp isActive] || !self.currentSession || !self.hotkeySuppressionTap.isTapping)
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


#pragma mark - Hotkey capturing

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

+ (NSSet *) keyPathsForValuesAffectingCanCaptureHotkeys
{
    return [NSSet setWithObject: @"hotkeySuppressionTap.canCaptureKeyEvents"];
}

- (BOOL) canCaptureHotkeys
{
    return self.hotkeySuppressionTap.canCaptureKeyEvents;
}

- (void) showHotkeyWarningIfUnavailable
{
    if ([self.class hasPerAppAccessibilityControls])
        [self _showPerAppHotkeyWarningIfUnavailable];
    else
        [self _showLegacyHotkeyWarningIfUnavailable];
}

- (void) showSystemAccessibilityControls
{
    if ([self.class hasPerAppAccessibilityControls])
        [self _showPerAppAccessibilityControls];
    else
        [self _showLegacyAccessibilityControls];
}

- (void) _showLegacyHotkeyWarningIfUnavailable
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL showHotkeyWarning = [defaults boolForKey: @"showHotkeyWarning"];
    BOOL hasSeenHotkeyWarning = [defaults boolForKey: @"hasDismissedHotkeyWarning"];
    
    if (showHotkeyWarning && !hasSeenHotkeyWarning && !self.canCaptureHotkeys)
    {
        NSAlert *hotkeyWarning = [[NSAlert alloc] init];
        NSString *messageFormat = NSLocalizedString(@"%1$@ works best if you turn on “Enable access for assistive devices” in OS X’s %2$@ preferences.",
                                                    @"Bold text of alert shown if the user does not have 'Allow access for assistive devices' enabled in OS X 10.8 and below. %1$@ is the title of the application; %2$@ is the localized name of the Accessibility preferences pane.");
        
        NSString *informativeTextFormat = NSLocalizedString(@"This ensures that OS X hotkeys won’t interfere with %1$@’s game controls.",
                                                            @"Informative text of alert shown if the user does not have 'Allow access for assistive devices' enabled in OS X 10.8 or below. %1$@ is the name of the application.");
        
        NSString *appName = [self.class appName];
        NSString *prefsName = [self.class localizedSystemAccessibilityPreferencesName];
        
        hotkeyWarning.messageText = [NSString stringWithFormat: messageFormat, appName, prefsName];
        hotkeyWarning.informativeText = [NSString stringWithFormat: informativeTextFormat, appName];
        
        NSString *defaultButtonFormat = NSLocalizedString(@"Open %@ Preferences", @"Label of default button in alert shown if the user does not have 'Allow access for assistive devices' enabled in OS X 10.8 or below. %@ is the localized name of the Accessibility preferences pane.");
        NSString *defaultButtonLabel = [NSString stringWithFormat: defaultButtonFormat, prefsName];
        
		NSString *cancelLabel = NSLocalizedString(@"Cancel",
                                                  @"Cancel the current action and return to what the user was doing");
        
        [hotkeyWarning addButtonWithTitle: defaultButtonLabel];
        [hotkeyWarning addButtonWithTitle: cancelLabel].keyEquivalent = @"\e";
        
        hotkeyWarning.delegate = self;
        hotkeyWarning.showsHelp = YES;
        hotkeyWarning.helpAnchor = @"spaces-shortcuts";
        
        if (self.currentSession)
        {
            [hotkeyWarning beginSheetModalForWindow: self.currentSession.windowForSheet
                                      modalDelegate: self
                                     didEndSelector: @selector(_hotkeyAlertDidEnd:returnCode:contextInfo:)
                                        contextInfo: NULL];
        }
        else
        {
            NSInteger returnCode = [hotkeyWarning runModal];
            [self _hotkeyAlertDidEnd: hotkeyWarning returnCode: returnCode contextInfo: NULL];
        }
        
        [hotkeyWarning release];
    }
}

- (void) _hotkeyAlertDidEnd: (NSAlert *)alert
                 returnCode: (NSInteger)returnCode
                contextInfo: (void *)contextInfo
{
    if (returnCode == NSAlertFirstButtonReturn)
    {
        [self _showLegacyAccessibilityControls];
    }
    else
    {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setBool: YES forKey: @"hasDismissedHotkeyWarning"];
    }
}

- (void) _showPerAppHotkeyWarningIfUnavailable
{
    //TODO: have some kind of fallback so that if our Applescript attempt to open the appropriate System Preferences pane
    //will fail (sandboxing, renamed system preferences anchors etc.), we'll use AXIsProcessTrustedWithOptions to present
    //the system default alert to the user.
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL showHotkeyWarning = [defaults boolForKey: @"showHotkeyWarning"];
    BOOL hasSeenHotkeyWarning = [defaults boolForKey: @"hasDismissedPerAppHotkeyWarning"];
    
    if (showHotkeyWarning && !hasSeenHotkeyWarning && !self.canCaptureHotkeys)
    {
        NSAlert *hotkeyWarning = [[NSAlert alloc] init];
        NSString *messageFormat = NSLocalizedString(@"%1$@ works best if you give it extra control in OS X’s %2$@ preferences.",
                                                    @"Bold text of alert shown if the application is not yet trusted for accessibility access on 10.9 and above. %1$@ is the name of the application; %2$@ is the localized title of the Security & Privacy preferences pane.");
        
        NSString *informativeTextFormat = NSLocalizedString(@"This ensures that OS X hotkeys won’t interfere with %1$@’s game controls.",
                                                            @"Informative text of alert shown if the application is not yet trusted for accessibility access on 10.9 and above. %1$@ is the name of the application.");
        
        NSString *appName = [self.class appName];
        NSString *prefsName = [self.class localizedSystemAccessibilityPreferencesName];
        
        hotkeyWarning.messageText = [NSString stringWithFormat: messageFormat, appName, prefsName];
        hotkeyWarning.informativeText = [NSString stringWithFormat: informativeTextFormat, appName];
        
        NSString *defaultButtonFormat = NSLocalizedString(@"Open %@ Preferences", @"Label of default button in alert shown if the application is not yet trusted for accessibility access on 10.9 and above. %@ is the localized name of the Security & Privacy preferences pane.");
        NSString *defaultButtonLabel = [NSString stringWithFormat: defaultButtonFormat, prefsName];

		NSString *cancelLabel = NSLocalizedString(@"Cancel",
                                                  @"Cancel the current action and return to what the user was doing");
 
        [hotkeyWarning addButtonWithTitle: defaultButtonLabel];
        [hotkeyWarning addButtonWithTitle: cancelLabel].keyEquivalent = @"\e";
        
        hotkeyWarning.delegate = self;
        hotkeyWarning.showsHelp = YES;
        hotkeyWarning.helpAnchor = @"spaces-shortcuts";
        
        if (self.currentSession)
        {
            [hotkeyWarning beginSheetModalForWindow: self.currentSession.windowForSheet
                                      modalDelegate: self
                                     didEndSelector: @selector(_perAppHotkeyAlertDidEnd:returnCode:contextInfo:)
                                        contextInfo: NULL];
        }
        else
        {
            NSInteger returnCode = [hotkeyWarning runModal];
            [self _perAppHotkeyAlertDidEnd: hotkeyWarning returnCode: returnCode contextInfo: NULL];
        }
        
        [hotkeyWarning release];
    }
}

- (void) _perAppHotkeyAlertDidEnd: (NSAlert *)alert
                       returnCode: (NSInteger)returnCode
                      contextInfo: (void *)contextInfo
{
    if (returnCode == NSAlertFirstButtonReturn)
    {
        [self _showPerAppAccessibilityControls];
    }
    else
    {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setBool: YES forKey: @"hasDismissedPerAppHotkeyWarning"];
    }
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
