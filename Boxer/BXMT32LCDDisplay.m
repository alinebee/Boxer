/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXMT32LCDDisplay.h"
#import "NSShadow+ADBShadowExtensions.h"
#import "NSImage+ADBImageEffects.h"
#import "NSBezierPath+MCAdditions.h"
#import "ADBGeometry.h"


@implementation BXMT32LCDDisplay

- (NSImage *) pixelFont
{
    return [NSImage imageNamed: @"MT32LCDFontTemplate"];
}

- (NSImage *) pixelGrid
{
    return [NSImage imageNamed: @"MT32LCDGridTemplate"];
}

- (NSColor *) screenColor
{   
    return [NSColor colorWithCalibratedHue: 0.144f
                                saturation: 0.7f
                                brightness: 0.200f
                                     alpha: 1.000f];
}

- (NSColor *) frameColor
{
    return [NSColor colorWithCalibratedWhite: 0 alpha: 0.1f];
}

- (NSColor *) gridColor
{
    return [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.1f];
}

- (NSColor *) pixelColor
{
    return [NSColor colorWithCalibratedHue: 0.144f
                                saturation: 0.737f
                                brightness: 0.923f
                                     alpha: 1.000f];
}

- (NSShadow *) innerShadow
{
    return [NSShadow shadowWithBlurRadius: 10.0f
                                   offset: NSMakeSize(0, -2.0f)
                                    color: [NSColor colorWithCalibratedWhite: 0 alpha: 0.66f]]; 
}

- (NSGradient *) screenLighting
{
    NSGradient *lighting = [[NSGradient alloc] initWithColorsAndLocations:
                            [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.10f], 0.0f,
                            [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.07f], 0.5f,
                            [NSColor clearColor], 0.55f,
                            nil];
    return lighting;
}

- (void) drawRect: (NSRect)dirtyRect
{
    NSString *charsToDisplay = [[self stringValue] stringByPaddingToLength: 20
                                                                withString: @" "
                                                           startingAtIndex: 0];
    
    NSImage *fontTemplate = [self pixelFont];
    NSImage *gridTemplate = [self pixelGrid];
    
    NSShadow *screenShadow  = [self innerShadow];
    NSColor *screenColor    = [self screenColor];
    
    NSBezierPath *screenPath = [NSBezierPath bezierPathWithRoundedRect: [self bounds]
                                                               xRadius: 4.0f
                                                               yRadius: 4.0f];
    
    
    //First, draw the screen itself
    [NSGraphicsContext saveGraphicsState];
        [screenColor set];
        [screenPath fill];
    [NSGraphicsContext restoreGraphicsState];
    
    NSColor *gridColor  = [self gridColor];
    NSColor *glyphColor = [self pixelColor];
    
    
    
    NSSize characterSize = [gridTemplate size];
    NSUInteger characterSpacing = 3;
    
    NSSize glyphSize = NSMakeSize(5, 9);
    unichar firstGlyph = '!';
    
    NSRect gridRect = NSMakeRect(0, 0,
                                 (characterSize.width + characterSpacing) * 19 + characterSize.width,
                                 characterSize.height);
    
    gridRect = centerInRect(gridRect, [self bounds]);
    gridRect.origin = integralPoint(gridRect.origin);
    
    
    NSRect fontTemplateRect = NSMakeRect(0, 0, [fontTemplate size].width, [fontTemplate size].height);
    NSRect gridTemplateRect = NSMakeRect(0, 0, [gridTemplate size].width, [gridTemplate size].height);
    
    NSRect characterRect    = NSMakeRect(gridRect.origin.x,
                                         gridRect.origin.y,
                                         characterSize.width,
                                         characterSize.height);
    
    NSImage *grid = [gridTemplate imageFilledWithColor: gridColor
                                                atSize: characterSize];
    
    NSUInteger i;
    
    for (i = 0; i < 20; i++)
    {
        //First, draw the background grid for this character
        [grid drawInRect: characterRect
                fromRect: NSZeroRect
               operation: NSCompositeSourceOver
                fraction: 1.0f
          respectFlipped: YES
                   hints: nil];
        
        //Next, draw the glyph to show in this grid, if it's within
        //the range of our drawable characters
        unichar c = [charsToDisplay characterAtIndex: i];
        NSInteger glyphOffset = c - firstGlyph;
        
        //The place in the font image to grab the glyph from
        NSRect glyphRect = NSMakeRect(glyphOffset * glyphSize.width, 0,
                                      glyphSize.width, glyphSize.height);
        
        //Only bother drawing the character if it's represented in our glyph image.
        if (NSContainsRect(fontTemplateRect, glyphRect))
        {
            NSImage *maskedGlyph = [gridTemplate copy];
            
            //First, use the grid to mask the glyph
            [maskedGlyph lockFocus];
                //Disable interpolation to ensure crisp scaling when we redraw the glyph.
                [[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationNone];
                [fontTemplate drawInRect: gridTemplateRect
                                fromRect: glyphRect
                               operation: NSCompositeDestinationIn
                                fraction: 1.0f
                          respectFlipped: YES
                                   hints: nil];
            [maskedGlyph unlockFocus];
            
            //Then, draw the masked glyph into the itself
            NSImage *tintedGlyph = [maskedGlyph imageFilledWithColor: glyphColor
                                                              atSize: NSZeroSize];
            
            [tintedGlyph drawInRect: characterRect
                           fromRect: NSZeroRect
                          operation: NSCompositeSourceOver
                           fraction: 1.0f
                     respectFlipped: YES
                              hints: nil];
        }
            
        characterRect.origin.x += characterSize.width + characterSpacing;
    }
    
    
    //Finally, draw the shadowing and lighting effects and the frame
    [[NSGraphicsContext currentContext] saveGraphicsState];
        [screenPath fillWithInnerShadow: screenShadow];
        [[self frameColor] setStroke];
        [screenPath setLineWidth: 2.0f];
        [screenPath strokeInside];
        [[self screenLighting] drawInBezierPath: screenPath angle: 80.0f];
    [[NSGraphicsContext currentContext] restoreGraphicsState];
}

@end
