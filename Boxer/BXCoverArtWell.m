/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXCoverArtWell.h"
#import "BXCoverArt.h"
#import "BXGeometry.h"
#import "NSShadow+BXShadowExtensions.h"

@implementation BXCoverArtWell

//This dropzone approximates the size and position that our generated box art will have
+ (NSBezierPath *) dropZoneForFrame: (NSRect)containingFrame
{
	//Border attributes for the bezier path
	CGFloat pattern[2]	= {12.0f, 6.0f};
	CGFloat borderWidth	= 4.0f;

	//Invent typical box-art dimensions (the ratio is all that matters, since we will be scaling up/down from there)
	NSSize dropZoneSize	= NSMakeSize(384, 512);

	//Allow enough room for the standard drop shadow we'd be rendering onto the real box art
	NSShadow *dropShadow = [BXCoverArt dropShadowForSize: containingFrame.size];
	
	NSSize availableSize = NSMakeSize(
		containingFrame.size.width	- [dropShadow shadowBlurRadius] * 2,
		containingFrame.size.height	- [dropShadow shadowBlurRadius] * 2
	);
	
	NSRect dropZoneFrame;
	dropZoneFrame.size = sizeToFitSize(dropZoneSize, availableSize);
	dropZoneFrame.origin = NSMakePoint(
		//Center the dropZone horizontally...
		containingFrame.origin.x + ((containingFrame.size.width - dropZoneFrame.size.width) / 2),
		//...but put its baseline along the bottom, with enough room for the drop shadow
		containingFrame.origin.y + ([dropShadow shadowBlurRadius] - [dropShadow shadowOffset].height)	
	);
	//Round the rect up to integral values, to avoid blurry subpixel lines
	dropZoneFrame = NSIntegralRect(dropZoneFrame);
	
	
	NSBezierPath *dropZone = [NSBezierPath
		bezierPathWithRoundedRect: NSInsetRect(dropZoneFrame, borderWidth/2, borderWidth/2)
		xRadius: borderWidth
		yRadius: borderWidth];
		
	[dropZone setLineWidth: borderWidth];
	[dropZone setLineDash: pattern count: 2 phase: 0.0f];
	
	return dropZone;
}

//A jolly downward-pointing arrow to go inside our dropzone
//TODO: replace this with a PDF image
+ (NSBezierPath *) arrowForFrame: (NSRect)containingFrame withSize: (NSSize)size
{
	CGFloat w=size.width, h=size.height;
	
	NSBezierPath *arrow = [NSBezierPath bezierPath];
	NSPoint arrowTip = NSMakePoint(NSMidX(containingFrame), NSMidY(containingFrame) - h * 0.5f);
	[arrow moveToPoint: arrowTip];
	[arrow relativeLineToPoint: NSMakePoint(w * -0.5f,	h * 0.5f)];
	[arrow relativeLineToPoint: NSMakePoint(w * 0.25f,	h * 0.0f)];
	[arrow relativeLineToPoint: NSMakePoint(w * 0.0f,	h * 0.5f)];
	[arrow relativeLineToPoint: NSMakePoint(w * 0.5f,	h * 0.0f)];
	[arrow relativeLineToPoint: NSMakePoint(w * 0.0f,	h * -0.5f)];
	[arrow relativeLineToPoint: NSMakePoint(w * 0.25f,	h * 0.0f)];
	[arrow closePath];
	
	return arrow;
}

//Enlarge the view's frame to accomodate our highlight glow
- (void) awakeFromNib
{
	CGFloat highlightRadius = [self highlightRadius];
	[self setFrame: NSInsetRect([self frame], -highlightRadius, -highlightRadius)];
}
	
- (void) drawRect: (NSRect)dirtyRect
{
	CGFloat highlightRadius = [self highlightRadius];
	NSRect drawRegion = NSInsetRect([self bounds], highlightRadius, highlightRadius);
	if ([self image])	[self drawImageInFrame: drawRegion];
	else				[self drawDropZoneInFrame: drawRegion];
}

- (BOOL) isHighlighted
{
	return isDragTarget || [[self window] firstResponder] == self;
}

- (CGFloat) highlightRadius	{ return 6.0f; }

- (NSShadow *) highlightGlow
{
    return [NSShadow shadowWithBlurRadius: [self highlightRadius]
                                   offset: NSZeroSize
                                    color: [NSColor keyboardFocusIndicatorColor]];
}

- (void) drawImageInFrame: (NSRect)frame
{
	NSImage *image = [self image];
	NSRect imageFrame;
	imageFrame.size		= sizeToFitSize(image.size, frame.size);
	imageFrame.origin	= frame.origin;
	imageFrame.origin.x += (frame.size.width - imageFrame.size.width) / 2; //Center the image horizontally
	
	[NSGraphicsContext saveGraphicsState];
		if ([self isHighlighted]) [[self highlightGlow] set];
		[image	drawInRect: imageFrame
				fromRect: NSZeroRect
				operation: NSCompositeSourceOver
				fraction: 1.0f];
	[NSGraphicsContext restoreGraphicsState];	
}

- (void) drawDropZoneInFrame: (NSRect)frame
{
	NSSize arrowSize = NSMakeSize(28, 28);
	
	NSBezierPath *dropZone	= [[self class] dropZoneForFrame: frame];
	NSBezierPath *arrow		= [[self class] arrowForFrame: [dropZone bounds] withSize: arrowSize];

	NSColor *borderColor	= [NSColor lightGrayColor];
	NSImage *shine			= [BXCoverArt shineForSize:			frame.size];
	NSShadow *dropShadow	= [BXCoverArt dropShadowForSize:	frame.size]; 
	

	//Isolate the current context on a transparent layer of its own,
	//so that our compositing operation won't pick up the containing view's background
	CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
	CGContextBeginTransparencyLayerWithRect(context, NSRectToCGRect(frame), NULL);
		
	[NSGraphicsContext saveGraphicsState];
		//Only draw our drop-shadow if we're not highlighted - otherwise draw the highlight glow instead
		if ([self isHighlighted]) [[self highlightGlow] set];
		else [dropShadow set];
		
		[borderColor set];
		[dropZone stroke];
		[arrow fill];
	[NSGraphicsContext restoreGraphicsState];
	
	//Add our own box shine to the rendered dropzone (this is the part that requires the transparency layer)
	[shine drawInRect: frame fromRect: NSZeroRect operation: NSCompositeSourceAtop fraction: 0.25f];
	
	CGContextEndTransparencyLayer(context);
}


//Convert the dropped image into pretty cover-art
- (void) setImage: (NSImage *)newImage
{
	if (newImage)
	{
		[super setImage: [BXCoverArt coverArtWithImage: newImage]];
	}
	else [super setImage: nil];
	
	//Deselect ourselves afterwards so we don't have a glow hanging around
	//TODO: this should be handled upstream, in the IBAction methods that call this instead
	if ([[self window] firstResponder] == self) [[self window] makeFirstResponder: nil];
}

- (NSDragOperation)draggingEntered: (id < NSDraggingInfo >)sender
{
	NSDragOperation result	= [super draggingEntered: sender];
	//NSPasteboard *pboard	= [sender draggingPasteboard];
	//Also accept regular files - we'll pick up their custom icons in performDragOperation:
	//if (result == NSDragOperationNone && [[pboard types] containsObject: NSFilenamesPboardType])
	//	result = NSDragOperationCopy;
	
	if (result != NSDragOperationNone)
	{
		isDragTarget = YES;
		[self setNeedsDisplay: YES];
	}
	return result;
}

- (void)draggingExited: (id < NSDraggingInfo >)sender
{
	isDragTarget = NO;
	[self setNeedsDisplay: YES];
	[super draggingExited: sender];
}

//Select ourselves before displaying our superview's menu, to indicate the target of cut/copy/paste menu options
- (NSMenu *) menuForEvent:(NSEvent *)event
{
	[[self window] makeFirstResponder: self];
	return [super menuForEvent: event];
}

/*
//Disabled for now, because setting images from files doesn't seem to get committed back to the gamebox itself.
//Need to look further into why this isn't working.
- (BOOL)performDragOperation: (id < NSDraggingInfo >)sender
{
	NSImage *oldImage = [self image];
	BOOL result = [super performDragOperation: sender];

	NSPasteboard *pboard = [sender draggingPasteboard];
	
	//super will return a YES result upon dragging a non-image file even though it didn't do anything with it,
	//so we check here whether the image actually changed as a result of the drag
	if ((!result || [self image] == oldImage) && [[pboard types] containsObject: NSFilenamesPboardType])
	{
		NSString *path	= [[pboard propertyListForType: NSFilenamesPboardType] lastObject];
		NSImage *icon	= [[NSWorkspace sharedWorkspace] iconForFile: path];
			
		if (icon)
		{
			[self setImage: icon];
			[self setNeedsDisplay: YES];
			result = YES;
		}
	}
	return result;
}
*/

- (void)concludeDragOperation: (id < NSDraggingInfo >)sender
{
	isDragTarget = NO;
	[self setNeedsDisplay: YES];
	[super concludeDragOperation: sender];
}

@end
