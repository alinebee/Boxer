/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXCursorFadeAnimation class description goes here.

#import <Cocoa/Cocoa.h>

@interface BXCursorFadeAnimation : NSAnimation
{
	NSCursor *originalCursor;
}
@property (retain) NSCursor *originalCursor;

- (NSCursor *) cursorWithOpacity: (CGFloat)opacity;

+ (NSCursor *) _generateCursor: (NSCursor *)cursor withOpacity: (CGFloat)opacity;

@end
