/*
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Cocoa/Cocoa.h>

//BXDOSWindowBackgroundView simply renders the badged grey gradient background of the DOS window.
@interface BXDOSWindowBackgroundView : NSView
{
    NSBitmapImageRep *_snapshot;
}
@end


@interface BXDOSWindowBackgroundView ()

@property (retain, nonatomic) NSBitmapImageRep *snapshot;

//Separate functions for drawing each component of the view, called during drawRect:.
//These should not be called directly: they are intended for overriding by subclasses.
- (void) _drawBackgroundInRect: (NSRect)dirtyRect;
- (void) _drawGrillesInRect: (NSRect)dirtyRect;
- (void) _drawLightingInRect: (NSRect)dirtyRect;
- (void) _drawBrandInRect: (NSRect)dirtyRect;

@end