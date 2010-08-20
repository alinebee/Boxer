/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXImportFinishedPanelController.h"
#import "BXAppController.h"
#import "BXImportWindowController.h"
#import "BXImport.h"
#import "BXCoverArt.h"
#import "NSWorkspace+BXFileTypes.h"

@implementation BXImportFinishedPanelController
@synthesize controller, iconView;

- (void) dealloc
{
	[self setIconView: nil], [iconView release];
	[super dealloc];
}

+ (NSSet *) keyPathsForValuesAffectingGameboxIcon
{
	return [NSSet setWithObject: @"controller.document.representedIcon"];
}

- (IBAction) addCoverArt: (id)sender
{
	NSImage *icon = [sender image];
	if (icon != [self gameboxIcon])
	{
		if (icon)
		{
			[[controller document] setRepresentedIcon: [BXCoverArt coverArtWithImage: icon]];
		}
		else
		{
			[[controller document] generateBootlegIcon];
		}		
	}
}

//This asinine workaround is necessary because with an ordinary binding, NSImageView
//doesn't bother checking the new value after it has set it, meaning it doesn't see
//our placeholder image or rendered box art.
//By making the mutator do nothing, and moving the mutator logic to the addCoverArt
//action, we trick NSImageView into paying proper attention to what is going on.
//FIXME: there has to be an easier way.
- (void) setGameboxIcon: (NSImage *)icon
{
}

- (NSImage *) gameboxIcon
{
	NSImage *icon = [[controller document] representedIcon];
	if (!icon) icon = [NSImage imageNamed: @"package.icns"];
	return icon;
}


#pragma mark -
#pragma mark UI actions

- (IBAction) revealGamebox: (id)sender
{
	NSString *packagePath = [[[controller document] gamePackage] bundlePath];
	[[NSApp delegate] revealInFinder: packagePath];
}

- (IBAction) launchGamebox: (id)sender
{
	NSURL *packageURL = [NSURL fileURLWithPath: [[[controller document] gamePackage] bundlePath]];
	
	//Close down the import process finally.
	[[controller document] close];
	
	//Open the newly-minted gamebox in a DOS session.
	[[NSApp delegate] openDocumentWithContentsOfURL: packageURL display: YES error: NULL];
}


#pragma mark -
#pragma mark NSTextField delegate methods

- (BOOL) control: (NSControl *)control textView: (NSTextView *)textView doCommandBySelector: (SEL)command
{
	//Cancel editing if the user presses the ESC key
	if (command == @selector(cancelOperation:))
	{
		[control abortEditing];
		return YES;
	}
	
	//Commit editing if the user presses Enter or Tab
	else if (command == @selector(insertNewline:) || command == @selector(insertTab:))
	{
		if ([[textView string] length])
		{
			[control validateEditing];
			
			//If the user tabbed, move focus to the next view; otherwise, clear the focus
			NSView *nextView = nil;
			if (command == @selector(insertTab:)) nextView = [control nextKeyView];
				
			[[control window] makeFirstResponder: nextView];
		}
		else
		{
			[control abortEditing];
		}
		return YES;
	}
	return NO;
}


#pragma mark -
#pragma mark Drag-drop handlers

@end


@implementation BXImportIconDropzone

- (BOOL) isHighlighted
{
	return isDragTarget || [[self window] firstResponder] == self;
}

- (NSDragOperation) draggingEntered: (id < NSDraggingInfo >)sender
{
	NSDragOperation result	= [super draggingEntered: sender];
	if (result != NSDragOperationNone)
	{
		isDragTarget = YES;
		[self setNeedsDisplay: YES];
	}
	return result;
}

- (void) draggingExited: (id < NSDraggingInfo >)sender
{
	isDragTarget = NO;
	[self setNeedsDisplay: YES];
	[super draggingExited: sender];
}

- (BOOL) performDragOperation: (id < NSDraggingInfo >)sender
{
	isDragTarget = NO;
	[self setNeedsDisplay: YES];
	return [super performDragOperation: sender];
}

- (BOOL) resignFirstResponder
{
	if ([super resignFirstResponder])
	{
		[self setNeedsDisplay: YES];
		return YES;
	}
	return NO;
}

- (void) drawRect: (NSRect)dirtyRect
{
	[NSGraphicsContext saveGraphicsState];
	if ([self isHighlighted])
	{
		CGFloat borderRadius = 8.0f;
		NSBezierPath *background = [NSBezierPath bezierPathWithRoundedRect: [self bounds]
																   xRadius: borderRadius
																   yRadius: borderRadius];
		
		NSColor *fillColor = [NSColor colorWithCalibratedRed: 0.67f
													   green: 0.86f
														blue: 0.93f
													   alpha: 0.33f];
		
		[fillColor setFill];
		[background fill];
	}

	[[self image] drawInRect: [self bounds]
					fromRect: NSZeroRect
				   operation: NSCompositeSourceOver
					fraction: 1.0f];
	 
	[NSGraphicsContext restoreGraphicsState];
}
@end
