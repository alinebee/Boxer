/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXPrintStatusPanelController.h"
#import "BXPrintSession.h"
#import "ADBGeometry.h"
#import "ADBForwardCompatibility.h"
#import <QuartzCore/QuartzCore.h>

@implementation BXPrintStatusPanelController
@synthesize numPages = _numPages;
@synthesize inProgress = _inProgress;
@synthesize activePrinterPort = _activePrinterPort;
@synthesize localizedPaperName = _localizedPaperName;
@synthesize preview = _preview;

- (void) windowDidLoad
{
    self.window.movableByWindowBackground = YES;
    ((NSPanel *)self.window).becomesKeyOnlyIfNeeded = YES;
    self.window.frameAutosaveName = @"PrintStatusPanel";
    self.window.level = NSNormalWindowLevel;
    
    if ([self.window respondsToSelector: @selector(setAnimationBehavior:)])
    {
        self.window.animationBehavior = NSWindowAnimationBehaviorUtilityWindow;
    }
    
    if ([self.window respondsToSelector: @selector(setCollectionBehavior:)])
    {
        self.window.collectionBehavior |= NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
    }
}


#pragma mark -
#pragma mark UI bindings

+ (NSString *) localizedNameForPort: (BXEmulatedPrinterPort)port
{
    switch (port)
    {
        case BXPrinterPortLPT1:
            return NSLocalizedString(@"LPT1", @"Localized name for parallel port 1");
            break;
            
        case BXPrinterPortLPT2:
            return NSLocalizedString(@"LPT2", @"Localized name for parallel port 2");
            break;
            
        case BXPrinterPortLPT3:
            return NSLocalizedString(@"LPT3", @"Localized name for parallel port 3");
            break;
    }
}

+ (NSSet *) keyPathsForValuesAffectingPrinterStatus
{
    return [NSSet setWithObjects: @"numPages", @"inProgress", nil];
}

- (NSString *) printerStatus
{
    //Print session has not been started
    if (self.numPages == 0)
    {
        return NSLocalizedString(@"The emulated printer is currently idle.", @"Status text shown in print status panel when the emulated printer has not printed anything yet in the current print session.");
    }
    //In the middle of printing
    else
    {
        NSString *format;
        if (self.inProgress)
        {
            format = NSLocalizedString(@"Preparing page %u…", @"Status text shown in print status panel when the emulated printer is in the middle of printing a page. %u is the current page number being printed.");
        }
        else
        {
            if (self.numPages > 1)
            {
                format = NSLocalizedString(@"%u pages are ready to print.", @"Status text shown in print status panel when multiple pages have been prepared. %u is the number of pages prepared so far.");
            }
            else
            {
                format = NSLocalizedString(@"1 page is ready to print.", @"Status text shown in print status panel when a single page has been prepared.");
            }
        }
        
        return [NSString stringWithFormat: format, self.numPages];
    }
}

+ (NSSet *) keyPathsForValuesAffectingPrinterInstructions
{
    return [NSSet setWithObjects: @"localizedPaperName", @"activePrinterPort", nil];
}

- (NSString *) printerInstructions
{
    NSString *portName = [self.class localizedNameForPort: self.activePrinterPort];
    NSString *format = NSLocalizedString(@"Instruct your DOS program to print to %1$@ using %2$@ paper.", @"Explanatory text shown while the printer is idle. %1$@ is the localized name of the port the user should choose in DOS (e.g. “LPT1”.) %2$@ is the localized name of the paper type they should choose in DOS (e.g. “A4”, “Letter”.)");
    
    return [NSString stringWithFormat: format, portName, self.localizedPaperName];
}

+ (NSSet *) keyPathsForValuesAffectingHasPages
{
    return [NSSet setWithObject: @"numPages"];
}

+ (NSSet *) keyPathsForValuesAffectingCanPrint
{
    return [NSSet setWithObjects: @"hasPages", @"inProgress", nil];
}

- (BOOL) hasPages
{
    return self.numPages > 0;
}

- (BOOL) canPrint
{
    return self.hasPages && !self.inProgress;
}

@end


@interface BXPrintPreview ()

@property (strong, nonatomic) CALayer *currentPage;
@property (strong, nonatomic) CALayer *previousPage;
@property (strong, nonatomic) CALayer *paperFeed;
@property (strong, nonatomic) CALayer *head;

@property (assign, nonatomic) CGSize pageSize;
@property (assign, nonatomic) CGSize dpi;

@end

@implementation BXPrintPreview

@synthesize currentPage = _currentPage;
@synthesize previousPage = _previousPage;
@synthesize paperFeed = _paperFeed;
@synthesize head = _head;

@synthesize headOffset = _headOffset;
@synthesize feedOffset = _feedOffset;
@synthesize pageSize = _pageSize;
@synthesize dpi = _dpi;

- (void) awakeFromNib
{
    self.dpi = CGSizeMake(48, 48);
    self.pageSize = CGSizeMake(8.50 * self.dpi.width,
                               12.0 * self.dpi.height);
    self.feedOffset = 0;
    self.headOffset = 0;
    
    NSImage *paper = [NSImage imageNamed: @"PrinterPaper"];
    _paperTexture = [paper CGImageForProposedRect: NULL context: nil hints: nil];
    
    CGPoint centerPoint = CGPointMake(NSMidX(self.bounds),
                                      NSMidY(self.bounds));
    
    CALayer *background = [CALayer layer];
    background.contents = [NSImage imageNamed: @"PrinterBackground"];
    background.contentsGravity = kCAGravityBottom;
    background.frame = NSRectToCGRect(self.bounds);
    background.delegate = self;
    
    CALayer *cover = [CALayer layer];
    cover.contents = [NSImage imageNamed: @"PrinterCover"];
    cover.bounds = CGRectMake(0, 0, self.bounds.size.width, 36);
    cover.anchorPoint = CGPointMake(0.5, 0);
    cover.position = CGPointMake(centerPoint.x, 0);
    cover.compositingFilter = [CIFilter filterWithName: @"CIMultiplyBlendMode"];
    cover.delegate = self;
    
    CALayer *lighting = [CALayer layer];
    lighting.contents = [NSImage imageNamed: @"PrinterLighting"];
    lighting.bounds = CGRectMake(0, 0, self.bounds.size.width, 240);
    lighting.anchorPoint = CGPointMake(0.5, 1);
    lighting.position = CGPointMake(centerPoint.x, self.bounds.size.height);
    lighting.compositingFilter = [CIFilter filterWithName: @"CISoftLightBlendMode"];
    lighting.delegate = self;
    lighting.autoresizingMask = kCALayerMinYMargin;
    
    self.paperFeed = [CALayer layer];
    self.paperFeed.bounds = CGRectInset(CGRectMake(0, 0, self.pageSize.width, self.bounds.size.height), -0.5 * self.dpi.width, 0);
    self.paperFeed.anchorPoint = CGPointMake(0.5, 0);
    self.paperFeed.position = CGPointMake(centerPoint.x, 0);
    self.paperFeed.delegate = self;
    self.paperFeed.shadowOffset = CGSizeMake(0, -2);
    self.paperFeed.shadowRadius = 3;
    self.paperFeed.shadowOpacity = 0.66;
    self.paperFeed.autoresizingMask = kCALayerHeightSizable;
    self.paperFeed.needsDisplayOnBoundsChange = YES;
    
    self.head = [CALayer layer];
    self.head.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
    self.head.bounds = CGRectMake(0, 0, 30, 12);
    self.head.anchorPoint = CGPointMake(0.5, 0);
    self.head.delegate = self;
    
    self.currentPage = [CALayer layer];
    self.currentPage.anchorPoint = CGPointMake(0.5, 1);
    self.currentPage.bounds = CGRectMake(0, 0, self.pageSize.width, self.pageSize.height);
    self.currentPage.delegate = self;
    self.currentPage.contentsGravity = kCAGravityTop;
    //Add a small shadow to thicken the preview and make it bolder
    self.currentPage.shadowOffset = CGSizeZero;
    self.currentPage.shadowOpacity = 0.5;
    self.currentPage.shadowRadius = 0.25;
    
    self.previousPage = [CALayer layer];
    self.previousPage.anchorPoint = CGPointMake(0.5, 1);
    self.previousPage.bounds = CGRectMake(0, 0, self.pageSize.width, self.pageSize.height);
    self.previousPage.delegate = self;
    self.previousPage.contentsGravity = kCAGravityTop;
    self.previousPage.shadowOffset = CGSizeZero;
    self.previousPage.shadowOpacity = 0.5;
    self.previousPage.shadowRadius = 0.25;
    
    CGFloat clipHeight = 106;
    
    CALayer *leftClip = [CALayer layer];
    leftClip.contents = [NSImage imageNamed: @"PrinterClip"];
    leftClip.bounds = CGRectMake(0, 0, 50, 104);
    leftClip.anchorPoint = CGPointMake(0, 0.5);
    leftClip.position = CGPointMake(0, clipHeight);
    leftClip.delegate = self;
    
    CALayer *rightClip = [CALayer layer];
    rightClip.contents = leftClip.contents;
    rightClip.bounds = leftClip.bounds;
    rightClip.anchorPoint = CGPointMake(0, 0.5);
    rightClip.position = CGPointMake(self.bounds.size.width, clipHeight);
    rightClip.affineTransform = CGAffineTransformMakeScale(-1, 1);
    rightClip.delegate = self;
    
    CALayer *clipRoller = [CALayer layer];
    clipRoller.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
    clipRoller.bounds = CGRectMake(0, 0, self.bounds.size.width, 96);
    clipRoller.position = CGPointMake(centerPoint.x, clipHeight);
    clipRoller.delegate = self;
    clipRoller.shadowOffset = CGSizeZero;
    clipRoller.shadowOpacity = 1;
    clipRoller.shadowRadius = 30;
    
    [background addSublayer: clipRoller];
    [background addSublayer: self.paperFeed];
    [background addSublayer: self.currentPage];
    [background addSublayer: self.previousPage];
    //We don't bother showing the print head for now because it usually moves too fast for any animation to be visible 
    //[background addSublayer: self.head];
    [background addSublayer: cover];
    [background addSublayer: leftClip];
    [background addSublayer: rightClip];
    [background addSublayer: lighting];
    
    self.layer = background;
    self.wantsLayer = YES;
    
    //For 10.9: fixes crash when using compositing filters.
    if ([self respondsToSelector: @selector(setLayerUsesCoreImageFilters:)])
        self.layerUsesCoreImageFilters = YES;
    
    [self _syncPagePosition];
    [self _syncHeadPosition];
}

- (void) dealloc
{
    CGImageRelease(_paperTexture);
    _paperTexture = NULL;
}

- (void) drawLayer: (CALayer *)layer inContext: (CGContextRef)ctx
{
    if (layer == self.paperFeed)
    {
        CGRect paperRect = [self.paperFeed convertRect: self.currentPage.bounds fromLayer: self.currentPage];
        paperRect = CGRectInset(paperRect, -0.5 * self.dpi.width, 0);
        
        CGContextDrawTiledImage(ctx, paperRect, _paperTexture);
    }
}

- (BOOL) layer: (CALayer *)layer shouldInheritContentsScale: (CGFloat)newScale fromWindow: (NSWindow *)window
{
    return YES;
}

- (NSImage *) currentPagePreview
{
    return self.currentPage.contents;
}

- (NSImage *) previousPagePreview
{
    return self.previousPage.contents;
}

- (void) setCurrentPagePreview: (NSImage *)preview
{
    //The preview image supplied is likely to be the same object the previous image,
    //but updated with new content; so force the layer to update itself by flipping
    //the contents momentarily to nil.
    //TODO: work out why a simple setNeedsDisplay isn't doing the job.
    self.currentPage.contents = nil;
    self.currentPage.contents = preview;
}

- (void) setPreviousPagePreview: (NSImage *)preview
{
    self.previousPage.contents = nil;
    self.previousPage.contents = preview;
}

- (void) _syncHeadPosition
{
    CGFloat xPos = self.pageSize.width * self.headOffset;
    self.head.position = CGPointMake(CGRectGetMinX(self.currentPage.frame) + xPos, 0);
}

- (void) _syncPagePosition
{
    //TWEAK: keep the 0-position slightly below the fold, so as not to show unprinted lines during slow printing.
    CGFloat bottomOffset = 15;
    CGFloat yPos = (self.pageSize.height * self.feedOffset) - bottomOffset;
    
    //Disable implicit movement animations on <10.7
    [CATransaction begin];
    [CATransaction setAnimationDuration: 0];
    self.currentPage.position   = CGPointMake(NSMidX(self.bounds), yPos);
    self.previousPage.position  = CGPointMake(NSMidX(self.bounds),
                                             CGRectGetMaxY(self.currentPage.frame) + self.previousPage.bounds.size.height);
    [CATransaction commit];
    
    [self.paperFeed setNeedsDisplay];
}

- (void) setFeedOffset: (CGFloat)feedOffset
{
    if (feedOffset != self.feedOffset)
    {
        _feedOffset = feedOffset;
        [self _syncPagePosition];
    }
}

- (void) setHeadOffset: (CGFloat)headOffset
{
    if (headOffset != self.headOffset)
    {
        _headOffset = headOffset;
        [self _syncHeadPosition];
    }
}

- (void) animateHeadToOffset: (CGFloat)headOffset
{
    //Don't bother animating the head's position as it moves so fast any animation would be interrupted.
    self.headOffset = headOffset;
}

- (void) animateFeedToOffset: (CGFloat)feedOffset
{
    [self.animator setFeedOffset: feedOffset];
}

+ (id) defaultAnimationForKey: (NSString *)key
{
    if ([key isEqualToString: @"feedOffset"])
    {
		CABasicAnimation *animation = [CABasicAnimation animation];
        animation.duration = 0.5;
        return animation;
    }
    
    return [super defaultAnimationForKey:key];
}

- (void) startNewPage: (id)sender
{
    self.previousPage.contents = self.currentPage.contents;
    self.currentPage.contents = nil;
    
    //Move the feed offset immediately by one page so that the previous page
    //lines up exactly with where the old current page was. Then, start a new
    //animation from that point to the top of the new page.
    [NSAnimationContext beginGrouping];
        [NSAnimationContext currentContext].duration = 0;
        [self.animator setFeedOffset: self.feedOffset - 1.0];
    [NSAnimationContext endGrouping];
    
    [self.animator setFeedOffset: 0.0];
}

@end
