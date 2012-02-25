/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXAppController+BXMediaKeys.h"
#import "BXKeyboardEventTap.h"
#import "BXSession+BXEmulatorControls.h"
#import <IOKit/hidsystem/ev_keymap.h>

@implementation BXAppController (BXMediaKeys)

- (void) mediaKeyPressed: (NSEvent *)theEvent
{   
    //Only respond to media keys if we have an active session and if we can be sure
    //other applications (like iTunes) won't also respond to them.
    if (!self.currentSession || !self.hotkeySuppressionTap.isTapping) return;
    
    //Decipher information from the event and decide what to do with the key.
    //Adapted from http://joshua.nozzi.name/2010/10/catching-media-key-events/
    int keyCode         = (theEvent.data1 & 0xFFFF0000) >> 16;
    NSUInteger flags    = theEvent.data1 & 0x0000FFFF;
    BOOL isPressed      = ((flags & 0xFF00) >> 8) == 0xA;
    
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

@end
