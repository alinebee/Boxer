/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXScriptableWindow is a wrapper for NSWindow which transparently passes KVO scripting messages
//first to the window controller, then to the window itself if the window controller doesn't
//respond to that key (or doesn't exist in the first place). 

//This allows a unified Applescript interface for dealing with a window and its controller as a unit,
//without overloading the window with controller logic.

#import <Cocoa/Cocoa.h>


@interface BXScriptableWindow : NSObject
{
	NSWindow *window;
}

@property (retain, nonatomic) NSWindow *window;

+ (id) scriptableWindow: (NSWindow *)window;
- (id) initWithWindow: (NSWindow *)window;

@end
