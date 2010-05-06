/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXEmulatorEventResponder.h"

#import <SDL/SDL.h>
#import "config.h"
#import "video.h"
#import "mouse.h"
#import "sdlmain.h"

@implementation BXEmulatorEventResponder


#pragma mark -
#pragma mark Mouse handling

- (void) mouseDown: (NSEvent *)theEvent			{ Mouse_ButtonPressed(DOSBoxMouseButtonLeft); }
- (void) mouseUp: (NSEvent *)theEvent			{ Mouse_ButtonReleased(DOSBoxMouseButtonLeft); }

- (void) rightMouseDown: (NSEvent *)theEvent	{ Mouse_ButtonPressed(DOSBoxMouseButtonRight); }
- (void) rightMouseUp: (NSEvent *)theEvent		{ Mouse_ButtonReleased(DOSBoxMouseButtonRight); }

- (void) otherMouseDown: (NSEvent *)theEvent
{
	if ([theEvent buttonNumber] == 2) Mouse_ButtonPressed(DOSBoxMouseButtonMiddle);
}

- (void) otherMouseUp: (NSEvent *)theEvent
{
	if ([theEvent buttonNumber] == 2) Mouse_ButtonReleased(DOSBoxMouseButtonMiddle);	
}

- (void) mouseMovedToPoint: (NSPoint)point byAmount: (NSPoint)delta whileLocked: (BOOL)locked
{
	CGFloat sensitivity = sdl.mouse.sensitivity / 100.0f;
	
	Mouse_CursorMoved(delta.x * sensitivity,
					  delta.y * sensitivity,
					  point.x * sensitivity,
					  point.y * sensitivity,
					  locked);
}
		 
		 
#pragma mark -
#pragma mark Key handling

- (void) keyUp: (NSEvent *)theEvent
{
}

- (void) keyDown: (NSEvent *)theEvent
{
}

//Convert flag changes into proper keypresses
- (void) flagsChanged: (NSEvent *)theEvent
{
}

@end