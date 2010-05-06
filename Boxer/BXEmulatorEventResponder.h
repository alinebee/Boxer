/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXEmulatorEventResponder class description goes here.

#import <Cocoa/Cocoa.h>

enum {
	DOSBoxMouseButtonLeft	= 0,
	DOSBoxMouseButtonRight	= 1,
	DOSBoxMouseButtonMiddle	= 2
};

@interface BXEmulatorEventResponder : NSResponder
{
	NSPoint lastMousePosition;
}

- (void) mouseMovedToPoint: (NSPoint)point byAmount: (NSPoint)delta whileLocked: (BOOL)locked;

@end