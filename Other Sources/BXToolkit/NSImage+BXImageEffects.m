/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "NSImage+BXImageEffects.h"

@implementation NSImage (BXImageEffects)

- (NSImage *) maskedImageWithColor: (NSColor *)color atSize: (NSSize)targetSize
{
    if (NSEqualSizes(targetSize, NSZeroSize)) targetSize = [self size];
    
    NSImage *maskedImage = [[NSImage alloc] init];
    [maskedImage setSize: targetSize];
    
    NSRect imageRect = NSMakeRect(0.0f, 0.0f, targetSize.width, targetSize.height);
    
    [maskedImage lockFocus];
        [color set];
        NSRectFillUsingOperation(imageRect, NSCompositeSourceOver);
        [self drawInRect: imageRect
                fromRect: NSZeroRect
               operation: NSCompositeDestinationIn
                fraction: 1.0f];
    [maskedImage unlockFocus];
    
    return [maskedImage autorelease];
}
@end
