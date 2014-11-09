/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXMT32ROMDropzone.h"

#pragma mark -
#pragma mark Private method declarations

@interface BXMT32ROMDropzone ()
@property (retain, nonatomic) CALayer *backgroundLayer;
@property (retain, nonatomic) CALayer *CM32LLayer;
@property (retain, nonatomic) CALayer *MT32Layer;
@property (retain, nonatomic) CALayer *highlightLayer;
@property (retain, nonatomic) CATextLayer *titleLayer;

//Set up which device is displayed and how it should be highlighted.
//Called whenever the ROM type changes or we highlight/unhighlight the field.
- (void) _syncDisplayedDevice;

@end


#pragma mark -
#pragma mark Implementation

@implementation BXMT32ROMDropzone
@synthesize ROMType = _ROMType;
@synthesize highlighted = _highlighted;
@synthesize backgroundLayer = _backgroundLayer;
@synthesize CM32LLayer = _CM32LLayer;
@synthesize MT32Layer = _MT32Layer;
@synthesize highlightLayer = _highlightLayer;
@synthesize titleLayer = _titleLayer;

- (void) awakeFromNib
{
    self.backgroundLayer    = [CALayer layer];
    self.CM32LLayer         = [CALayer layer];
    self.MT32Layer          = [CALayer layer];
    self.highlightLayer     = [CALayer layer];
    self.titleLayer         = [CATextLayer layer];
    
    self.backgroundLayer.delegate = self;
    self.CM32LLayer.delegate = self;
    self.MT32Layer.delegate = self;
    self.highlightLayer.delegate = self;
    self.titleLayer.delegate = self;
    
    //Retrieve the images we'll be using for the shelf and devices,
    //and set the layers to use them.
    self.backgroundLayer.contents   = [NSImage imageNamed: @"MT32Shelf"];
    self.CM32LLayer.contents        = [NSImage imageNamed: @"CM32L"];
    self.MT32Layer.contents         = [NSImage imageNamed: @"MT32"];
    self.highlightLayer.contents    = [NSImage imageNamed: @"MT32ShelfHighlight"];
    
    //Force the shelf and device layers to the same size as the view.
    self.backgroundLayer.frame = NSRectToCGRect(self.bounds);
    self.CM32LLayer.frame = self.MT32Layer.frame = self.highlightLayer.frame = self.backgroundLayer.bounds;
    
    
    //Start the device layers hidden - we'll unhide them selectively
    //when our type is changed.
    self.CM32LLayer.hidden      = YES;
    self.MT32Layer.hidden       = YES;
    self.highlightLayer.hidden  = YES;
    
    //Add a hidden glow to the CM-32L and MT-32 layers,
    //which will be unhidden when we highlight.
    self.MT32Layer.shadowRadius = self.CM32LLayer.shadowRadius = 6;
    self.MT32Layer.shadowColor  = self.CM32LLayer.shadowColor = CGColorGetConstantColor(kCGColorWhite);
    

    //Set up the title text layer to sit 20 pixels in from the shelf edges.
    self.titleLayer.frame = CGRectIntegral(CGRectInset(_backgroundLayer.bounds, 20.0f, 20.0f));
    self.titleLayer.wrapped = YES;
    self.titleLayer.alignmentMode = kCAAlignmentCenter;
    
    self.titleLayer.foregroundColor = CGColorGetConstantColor(kCGColorWhite);
    self.titleLayer.font            = (__bridge CFTypeRef)([NSFont boldSystemFontOfSize: 0]);
    self.titleLayer.fontSize        = 16.0f;
    
    self.titleLayer.shadowOffset = CGSizeMake(0, 1.0f);
    self.titleLayer.shadowRadius = 3.0f;
    self.titleLayer.shadowOpacity = 0.75f;
    
    //Keep the title layer in sync with our own label.
    [self.titleLayer bind: @"string" toObject: self withKeyPath: @"title" options: nil];
    
    [self.backgroundLayer addSublayer: self.CM32LLayer];
    [self.backgroundLayer addSublayer: self.MT32Layer];
    [self.backgroundLayer addSublayer: self.titleLayer];
    [self.backgroundLayer addSublayer: self.highlightLayer];
    
    self.layer = self.backgroundLayer;
    self.wantsLayer = YES;
}

- (void) drawRect: (NSRect)dirtyRect
{
//Overridden to disable NSButton's default draw behaviour on OS X 10.10.
}

//Required for OSX 10.8, which appears to have removed the default
//transition for the CALayer hidden property.

- (id <CAAction>) actionForLayer: (CALayer *)layer forKey: (NSString *)event
{
    if ([event isEqualToString: @"hidden"])
    {
        CATransition *fade = [CATransition animation];
        fade.type = kCATransitionFade;
        fade.timingFunction = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseIn];
        fade.duration = 0.33;
        
        return fade;
    }
    else
    {
        return nil;
    }
}

- (BOOL) layer: (CALayer *)layer shouldInheritContentsScale: (CGFloat)newScale fromWindow: (NSWindow *)window
{
    //HACK for OS X 10.10: for some reason, only the text-based title layer actually needs this to return YES:
    //all the image-based layer require it to return NO, or else they won't render their contents at all.
    if (layer == self.titleLayer)
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

- (void) setHighlighted: (BOOL)flag
{
    if (self.isHighlighted != flag)
    {
        _highlighted = flag;
        [self _syncDisplayedDevice];
    }
}

- (void) _syncDisplayedDevice
{
    [CATransaction begin];
        self.CM32LLayer.hidden      = (self.ROMType & BXMT32ROMIsCM32L) != BXMT32ROMIsCM32L;
        self.MT32Layer.hidden       = (self.ROMType & BXMT32ROMIsMT32) != BXMT32ROMIsMT32;
        self.highlightLayer.hidden  = !(self.ROMType == BXMT32ROMTypeUnknown && self.isHighlighted);
    [CATransaction commit];
    
    self.MT32Layer.shadowOpacity    = self.isHighlighted ? 1: 0;
    self.CM32LLayer.shadowOpacity   = self.isHighlighted ? 1: 0;
    
    [self setNeedsDisplay: YES];
}

- (void) setROMType: (BXMT32ROMType)ROMType
{
    if (ROMType != self.ROMType)
    {
        _ROMType = ROMType;
        [self _syncDisplayedDevice];
    }
}

- (void) dealloc
{
    [self.titleLayer unbind: @"string"];
    
    self.backgroundLayer = nil;
    self.MT32Layer = nil;
    self.CM32LLayer = nil;
    self.highlightLayer = nil;
    self.titleLayer = nil;
    
    [super dealloc];
}

@end
