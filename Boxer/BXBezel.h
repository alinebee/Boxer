/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXBezel is our erstwhile notification bezel class, intended for implementing fullscreen notifications.
//Unfortunately it cannot be used at present, because CALayers don't play nice with NSOpenGLViews.

#import <QuartzCore/QuartzCore.h>
#import "BXSessionWindowController.h"

@interface BXBezel : CATextLayer
{
	CFTimeInterval hideAfter;	//if > 0, bezel will fade out automatically after this time
	CFTimeInterval fadeInSpeed;
	CFTimeInterval fadeOutSpeed;
}
- (void) sizeToFit;

@property CFTimeInterval hideAfter;
@property CFTimeInterval fadeInSpeed;
@property CFTimeInterval fadeOutSpeed;
@end


@interface BXNotifiableWindowController : BXSessionWindowController
{
	BXBezel	*notificationBezel;
}
@property (retain) Bezel *notificationBezel;

- (void) showNotification: (NSString *)message;
- (void) hideNotification;
- (BXBezel *) makeBezel;
@end