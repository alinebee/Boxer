/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXRenderViewController class description goes here.

#import <Cocoa/Cocoa.h>

@interface BXRenderViewController : NSViewController
{
	BOOL mouseActive;
	BOOL mouseLocked;
	NSCursor *hiddenCursor;
}

@property (retain) NSCursor *hiddenCursor;
@property (assign) BOOL mouseActive;
@property (assign) BOOL mouseLocked;

//Returns whether the mouse currently lies inside the view. 
- (BOOL) mouseInView;

//Toggles mouse locking on/off, playing a jaunty lock/unlock sound along the way.
- (IBAction) toggleMouseLocked: (id)sender;

@end