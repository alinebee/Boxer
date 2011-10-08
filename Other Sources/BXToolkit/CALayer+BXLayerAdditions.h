/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXLayerAdditions contains extensions to CALayer to make them play nicer with the rest of Cocoa.

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

@interface CALayer (BXLayerAdditions)

//Loads the image with the specified name and applies it as the content for the layer.
- (void) setContentsFromImageNamed: (NSString *)imageName;

@end
