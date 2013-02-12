/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXDOSWindowBackgroundView.h"
#import "BXGeometry.h"
#import "NSShadow+BXShadowExtensions.h"
#import "NSView+BXDrawing.h"
#import "NSImage+BXSaveImages.h"

@implementation BXDOSWindowBackgroundView
@synthesize snapshot = _snapshot;

- (void) _drawBackgroundInRect: (NSRect)dirtyRect
{
    NSImage *background = [NSImage imageNamed: @"DOSWindowBackground"];
	NSColor *backgroundPattern = [NSColor colorWithPatternImage: background];
	NSSize patternSize		= background.size;
	NSSize viewSize			= self.bounds.size;
	NSPoint patternOffset	= [NSView focusView].offsetFromWindowOrigin;
	NSPoint patternPhase	= NSMakePoint(patternOffset.x + ((viewSize.width - patternSize.width) * 0.5f),
										  patternOffset.y + (viewSize.height - patternSize.height));
	
	[NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext currentContext].patternPhase = patternPhase;
        [backgroundPattern set];
        [NSBezierPath fillRect: dirtyRect];
	[NSGraphicsContext restoreGraphicsState];
}

- (void) _drawGrillesInRect: (NSRect)dirtyRect
{
	NSImage *grille = [NSImage imageNamed: @"DOSWindowGrille"];
	NSSize patternSize      = grille.size;
	NSRect backgroundRect   = self.bounds;
	
	//Next, calculate our top and bottom grille strips: these will be slightly cut off by the top and bottom of the background.
	NSRect topGrilleStrip       = backgroundRect;
	topGrilleStrip.size.height	= patternSize.height * 0.83f;
	topGrilleStrip.origin.y     = backgroundRect.size.height - topGrilleStrip.size.height;
	
    NSRect bottomGrilleStrip        = backgroundRect;
	bottomGrilleStrip.size.height	= patternSize.height * 0.83f;
	
    BOOL renderingToSnapshot = ([NSView focusView] == nil);
    BOOL topGrilleDirty     = renderingToSnapshot || [self needsToDrawRect: topGrilleStrip];
    BOOL bottomGrilleDirty  = renderingToSnapshot || [self needsToDrawRect: bottomGrilleStrip];
    
	//Only bother drawing the grilles if they intersect with the region being drawn
	if (topGrilleDirty || bottomGrilleDirty)
	{
        NSColor *grillePattern  = [NSColor colorWithPatternImage: grille];
		NSPoint patternOffset	= [NSView focusView].offsetFromWindowOrigin;
        
        CGFloat horizontalPhase = patternOffset.x + ((backgroundRect.size.width - patternSize.width) * 0.5f);
        
        if (topGrilleDirty)
        {
            NSPoint topGrillePhase = NSMakePoint(horizontalPhase,
                                                 patternOffset.y + topGrilleStrip.origin.y);
            NSBezierPath *topGrille = [NSBezierPath bezierPathWithRect: topGrilleStrip];
            
            [NSGraphicsContext saveGraphicsState];
                [NSGraphicsContext currentContext].patternPhase = topGrillePhase;
                [grillePattern set];
                [topGrille fill];
            [NSGraphicsContext restoreGraphicsState];
        }
        
        if (bottomGrilleDirty)
        {
            NSPoint bottomGrillePhase = NSMakePoint(horizontalPhase,
                                                    patternOffset.y + (bottomGrilleStrip.size.height - patternSize.height));
            NSBezierPath *bottomGrille = [NSBezierPath bezierPathWithRect: bottomGrilleStrip];
            
            [NSGraphicsContext saveGraphicsState];
                [NSGraphicsContext currentContext].patternPhase = bottomGrillePhase;
                [grillePattern set];
                [bottomGrille fill];
            [NSGraphicsContext restoreGraphicsState];
        }
	}
}

- (void) _drawLightingInRect: (NSRect)dirtyRect
{
    //Draw a vignetting effect from the top center of the window.
	NSGradient *lighting = [[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.2f]
														 endingColor: [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.2f]];
	
	NSRect backgroundRect = self.bounds;
	NSPoint startPoint	= NSMakePoint(NSMidX(backgroundRect), NSMaxY(backgroundRect));
	NSPoint endPoint	= NSMakePoint(NSMidX(backgroundRect), NSMidY(backgroundRect));
	CGFloat startRadius = NSWidth(backgroundRect) * 0.1f;
	CGFloat endRadius	= NSWidth(backgroundRect) * 0.75f;
	
	[lighting drawFromCenter: startPoint radius: startRadius
					toCenter: endPoint radius: endRadius
					 options: NSGradientDrawsBeforeStartingLocation | NSGradientDrawsAfterEndingLocation];
	
	[lighting release];
    
    
    //Augment the main lighting with shadows at the top and bottom edge of the window.
    NSRect topShadowRect = backgroundRect, bottomShadowRect = backgroundRect;
    topShadowRect.size.height = 20;
    bottomShadowRect.size.height = 20;
    topShadowRect.origin.y = backgroundRect.size.height - topShadowRect.size.height;
    
    BOOL renderingToSnapshot = ([NSView focusView] == nil);
    BOOL topShadowDirty     = renderingToSnapshot || [self needsToDrawRect: topShadowRect];
    BOOL bottomShadowDirty  = renderingToSnapshot || [self needsToDrawRect: bottomShadowRect];
    if (topShadowDirty || bottomShadowDirty)
    {
        NSGradient *edgeShadows = [[NSGradient alloc] initWithColorsAndLocations:
                                   [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.3f], 0.0f,
                                   [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.05f], 0.5f,
                                   [NSColor clearColor], 1.0f,
                                   nil];
        
        if (topShadowDirty)
            [edgeShadows drawInRect: topShadowRect angle: 270];
        
        if (bottomShadowDirty)
            [edgeShadows drawInRect: bottomShadowRect angle: 90];
        
        [edgeShadows release];
    }
}

- (void) _drawBrandInRect: (NSRect)dirtyRect
{
	NSImage *brand = [NSImage imageNamed: @"Brand"];
	NSRect brandRegion = NSZeroRect;
	brandRegion.size = brand.size;
    
	brandRegion = NSIntegralRect(centerInRect(brandRegion, self.bounds));
	
    BOOL renderingToSnapshot = ([NSView focusView] == nil);
	if (renderingToSnapshot || [self needsToDrawRect: brandRegion])
	{
        NSShadow *brandShadow = [NSShadow shadowWithBlurRadius: 5.0f
                                                        offset: NSZeroSize
                                                         color: [NSColor colorWithCalibratedWhite: 0 alpha: 0.25f]];
        
        [NSGraphicsContext saveGraphicsState];
            [brandShadow set];
            [brand drawInRect: brandRegion
                     fromRect: NSZeroRect
                    operation: NSCompositeSourceOver
                     fraction: 0.5f];
        [NSGraphicsContext restoreGraphicsState];
	}
}

- (void) _reallyDrawRect: (NSRect)dirtyRect
{
    [self _drawBackgroundInRect: dirtyRect];
    [self _drawLightingInRect: dirtyRect];
    [self _drawGrillesInRect: dirtyRect];
}

- (void) drawRect: (NSRect)dirtyRect
{
    //IMPLEMENTATION NOTE: drawing this view is quite expensive because of all the effects,
    //especially in fullscreen. Because this view has a bunch of transparent views on top of it,
    //it gets dirty all the time: so we optimize for overdraw by rendering the background to an
    //bitmap and then rendering that bitmap in future.
    //(If the user is resizing the window, we say to hell with it and draw ourselves anew each time
    //as the alternative would be too look blurry and gross.)
    
    if (self.inLiveResize)
    {
        [self _reallyDrawRect: dirtyRect];
    }
    else
    {
        NSSize backingSize = self.bounds.size;
        if ([self respondsToSelector: @selector(convertSizeToBacking:)])
            backingSize = [self convertSizeToBacking: backingSize];
        
        if (!NSEqualSizes(backingSize, self.snapshot.size))
        {
            //CHECKME: this would be less code if we used NSBitmapImageRep -initWithFocusedViewRect:.
            //Check if that's faster or slower.
            self.snapshot = [self bitmapImageRepForCachingDisplayInRect: self.bounds];
            
            NSDictionary *contextAttribs = [NSDictionary dictionaryWithObject: self.snapshot
                                                                       forKey: NSGraphicsContextDestinationAttributeName];
            
            NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithAttributes: contextAttribs];
            
            [NSGraphicsContext saveGraphicsState];
                [NSGraphicsContext setCurrentContext: context];
                [self _reallyDrawRect: self.bounds];
            [NSGraphicsContext restoreGraphicsState];
        }
        
        [self.snapshot drawInRect: dirtyRect
                         fromRect: dirtyRect
                        operation: NSCompositeCopy
                         fraction: 1.0f
                   respectFlipped: YES
                            hints: nil];
    }
}

- (BOOL) isOpaque
{
    return YES;
}

- (void) dealloc
{
    self.snapshot = nil;
    [super dealloc];
}

@end
