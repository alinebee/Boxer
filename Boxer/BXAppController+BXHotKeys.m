/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXAppController+BXHotKeys.h"
#import "BXKeyboardEventTap.h"
#import "BXSession+BXEmulatorControls.h"

//For various keycode definitions
#import <IOKit/hidsystem/ev_keymap.h>
#import <Carbon/Carbon.h>

//Elements of this implementation were adapted from
//http://joshua.nozzi.name/2010/10/catching-media-key-events/

@implementation BXAppController (BXHotKeys)

+ (NSUInteger) _mediaKeyCode: (NSEvent *)theEvent
{
    return (theEvent.data1 & 0xFFFF0000) >> 16;
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
    NSUInteger keyCode  = [[self class] _mediaKeyCode: theEvent];
    BOOL isPressed      = [[self class] _mediaKeyDown: theEvent];
    
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
    @synchronized(self.currentSession)
    {
        if (!self.currentSession) return NO;
        if (!self.currentSession.programIsActive) return NO;
        if ([self documentForWindow: [NSApp keyWindow]] != self.currentSession) return NO;
    }
        
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
    if (!self.currentSession.isEmulating) return NO;
    
    //Only listen for certain media keys.
    NSUInteger keyCode = [[self class] _mediaKeyCode: event];
    
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

@end
