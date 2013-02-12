/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXDOSWindow.h"
#import "BXDOSWindowController.h"

#define BXFrameResizeDelay 0.2
#define BXFrameResizeDelayFalloff 7.5

@implementation BXDOSWindow
@synthesize actualContentView;

- (void) dealloc
{
    [self setActualContentView: nil], [actualContentView release];
    [super dealloc];
}

//Overridden to smooth out the speed of shorter resize animations,
//while leaving larger resize animations largely as they were.
- (NSTimeInterval) animationResizeTime: (NSRect)newFrame
{
	NSTimeInterval baseTime = [super animationResizeTime: newFrame];
	NSTimeInterval scaledTime = 0.0;

	if (baseTime > 0.0)
		scaledTime = baseTime + (BXFrameResizeDelay * MIN(1.0, (1.0 / (baseTime * BXFrameResizeDelayFalloff))));
	
	return scaledTime;
}


# pragma mark -
# pragma mark Content-based resizing

- (NSSize) actualContentViewSize
{
    return [[self actualContentView] frame].size;
}



//Returns the difference between the window content frame
//and the frame of the actual view
- (NSRect) _actualContentOffset
{
    NSRect offset = NSZeroRect;
    
    if ([self contentView])
    {
        NSRect windowContentFrame = [[self contentView] frame];
        NSRect actualContentFrame = [[self actualContentView] frame];
        
        offset.size.width   = windowContentFrame.size.width - actualContentFrame.size.width;
        offset.size.height  = windowContentFrame.size.height - actualContentFrame.size.height;
        offset.origin.x     = windowContentFrame.origin.x - actualContentFrame.origin.x;
        offset.origin.y     = windowContentFrame.origin.y - actualContentFrame.origin.y;
    }
    
    return offset;
}


//Adjust reported content/frame sizes to account for statusbar and program panel
//This is used to keep content resizing proportional to the shape of the render view,
//not the shape of the window.

- (NSRect) contentRectForFrameRect: (NSRect)windowFrame
{
	NSRect rect = [super contentRectForFrameRect: windowFrame];
    
    //Determine the current difference between our actual content view and
    //the window's content view, and adjust the calculated rect accordingly.
    NSRect contentOffset = [self _actualContentOffset];
    
    rect.size.width     -= contentOffset.size.width;
    rect.size.height    -= contentOffset.size.height;
    rect.origin.x       -= contentOffset.origin.x;
    rect.origin.y       -= contentOffset.origin.y;
    
	return rect;
}

- (NSRect) frameRectForContentRect: (NSRect)windowContent
{
	NSRect rect = [super frameRectForContentRect: windowContent];
    
    NSRect contentOffset = [self _actualContentOffset];
    
    rect.size.width     += contentOffset.size.width;
    rect.size.height    += contentOffset.size.height;
    rect.origin.x       += contentOffset.origin.x;
    rect.origin.y       += contentOffset.origin.y;
	
	return rect;
}

@end
