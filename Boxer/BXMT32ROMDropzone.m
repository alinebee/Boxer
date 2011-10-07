/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXMT32ROMDropzone.h"
#import "CALayer+BXLayerAdditions.h"

@implementation BXMT32ROMDropzone
@synthesize ROMType = _ROMType;
@synthesize title = _title;
@synthesize highlighted = _highlighted;

- (void) awakeFromNib
{
    _backgroundLayer    = [[CALayer alloc] init];
    _CM32LLayer         = [[CALayer alloc] init];
    _MT32Layer          = [[CALayer alloc] init];
    _titleLayer         = [[CATextLayer alloc] init];
    
    //Retrieve the images we'll be using for the shelf and devices,
    //and set the layers to use them.
    [_backgroundLayer setContentsFromImageNamed: @"MT32Shelf.png"];
    [_CM32LLayer setContentsFromImageNamed: @"CM32L.png"];
    [_MT32Layer setContentsFromImageNamed: @"MT32.png"];
    
    //Force the shelf and device layers to the same size as the view.
    _backgroundLayer.frame = NSRectToCGRect(self.bounds);
    _CM32LLayer.frame = _MT32Layer.frame = _backgroundLayer.bounds;
    
    //Start the device layers hidden - we'll unhide them selectively
    //when our type is changed.
    _CM32LLayer.hidden = YES;
    _MT32Layer.hidden = YES;

    //Set up the title text layer to sit 20 pixels in from the shelf edges.
    _titleLayer.frame = CGRectIntegral(CGRectInset(_backgroundLayer.bounds, 20.0f, 20.0f));
    _titleLayer.wrapped = YES;
    _titleLayer.alignmentMode = kCAAlignmentCenter;
    
    _titleLayer.foregroundColor = CGColorGetConstantColor(kCGColorWhite);
    _titleLayer.font        = [NSFont boldSystemFontOfSize: 0];
    _titleLayer.fontSize    = 16.0f;
    
    _titleLayer.shadowOffset = CGSizeMake(0, -1.0f);
    _titleLayer.shadowRadius = 3.0f;
    _titleLayer.shadowOpacity = 0.75f;
    
    
    [_titleLayer bind: @"string" toObject: self withKeyPath: @"title" options: nil];
    
    [_backgroundLayer addSublayer: _CM32LLayer];
    [_backgroundLayer addSublayer: _MT32Layer];
    [_backgroundLayer addSublayer: _titleLayer];
    
    [self setLayer: _backgroundLayer];
    [self setWantsLayer: YES];
}

- (void) _syncDisplayedDevice
{
    _CM32LLayer.hidden  = !(self.ROMType == BXMT32ROMTypeCM32L);
    _MT32Layer.hidden   = !(self.ROMType == BXMT32ROMTypeMT32);
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
    [_backgroundLayer release], _backgroundLayer = nil;
    [_MT32Layer release], _MT32Layer = nil;
    [_CM32LLayer release], _CM32LLayer = nil;
    
    [self setTitle: nil], [_title release];
    [super dealloc];
}

@end
