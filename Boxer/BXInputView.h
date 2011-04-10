/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXInputView tracks keyboard and mouse input and passes them to its BXInputController.
//It wraps a BXFrameRenderingView implementor and does no direct rendering itself,
//besides a badged grey gradient background.

//TODO: split this class up further so that BXInputView does no drawing of its own, but instead
//defers to a wrapper background element

#import <Cocoa/Cocoa.h>

@interface BXInputView : NSView
@end
