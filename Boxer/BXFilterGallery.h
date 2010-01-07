/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXFilterGallery draws Boxer's rendering filter gallery in the preferences pane. It consists of
//a view with a graphical background containing custom NSButtons for each option.

#import <Cocoa/Cocoa.h>

@interface BXFilterGallery : NSView
@end

@interface BXFilterPortraitCell : NSButtonCell
@end