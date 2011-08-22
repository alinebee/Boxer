/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "NSShadow+BXShadowExtensions.h"


@implementation NSShadow (BXShadowExtensions)

+ (id) shadow
{
    return [[[self alloc] init] autorelease];
}

+ (id) shadowWithBlurRadius: (CGFloat)blurRadius
                     offset: (NSSize)offset
{
    NSShadow *theShadow = [[self alloc] init];
    [theShadow setShadowBlurRadius: blurRadius];
    [theShadow setShadowOffset: offset];
    
    return [theShadow autorelease];
}

+ (id) shadowWithBlurRadius: (CGFloat)blurRadius
                     offset: (NSSize)offset
                      color: (NSColor *)color
{
    NSShadow *theShadow = [[self alloc] init];
    [theShadow setShadowBlurRadius: blurRadius];
    [theShadow setShadowOffset: offset];
    [theShadow setShadowColor: color];
    
    return [theShadow autorelease];
}

- (NSRect) insetRectForShadow: (NSRect)origRect
{
    CGFloat radius  = [self shadowBlurRadius];
    NSSize offset   = [self shadowOffset];
    
    NSRect insetRect  = NSInsetRect(origRect, radius, radius);
    insetRect.origin.x -= offset.width;
    insetRect.origin.y -= offset.height;
    
    return insetRect;
}

- (NSRect) expandedRectForShadow: (NSRect)origRect
{
    CGFloat radius  = [self shadowBlurRadius];
    NSSize offset   = [self shadowOffset];
    
    NSRect expandedRect  = NSInsetRect(origRect, -radius, -radius);
    expandedRect.origin.x += offset.width;
    expandedRect.origin.y += offset.height;
    
    return expandedRect;
}

@end
