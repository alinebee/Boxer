/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXBezelView.h"

#define BXBezelBorderRadius 20.0f

@implementation BXBezelView

- (void) drawRect: (NSRect)dirtyRect
{
    NSBezierPath *background = [NSBezierPath bezierPathWithRoundedRect: [self bounds]
                                                               xRadius: BXBezelBorderRadius
                                                               yRadius: BXBezelBorderRadius];
    
    NSColor *backgroundColor = [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.5f];
    
    [NSGraphicsContext saveGraphicsState];
    [backgroundColor set];
    [background fill];
    [NSGraphicsContext restoreGraphicsState];
}
@end
