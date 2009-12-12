//
//  BGHUDTextFieldCell.m
//  BGHUDAppKit
//
//  Created by BinaryGod on 6/2/08.
//
//  Copyright (c) 2008, Tim Davis (BinaryMethod.com, binary.god@gmail.com)
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//
//		Redistributions of source code must retain the above copyright notice, this
//	list of conditions and the following disclaimer.
//
//		Redistributions in binary form must reproduce the above copyright notice,
//	this list of conditions and the following disclaimer in the documentation and/or
//	other materials provided with the distribution.
//
//		Neither the name of the BinaryMethod.com nor the names of its contributors
//	may be used to endorse or promote products derived from this software without
//	specific prior written permission.
//
//	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS AS IS AND
//	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
//	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
//	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
//	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
//	POSSIBILITY OF SUCH DAMAGE.

#import "BGHUDTextFieldCell.h"


@implementation BGHUDTextFieldCell

@synthesize themeKey;

#pragma mark Drawing Functions

- (id)initTextCell:(NSString *)aString {

	self = [super initTextCell: aString];
	
	if(self) {
		
		self.themeKey = @"gradientTheme";
		[self setTextColor: [[[BGThemeManager keyedManager] themeForKey: self.themeKey] textColor]];
		
		if([self drawsBackground]) {
			
			fillsBackground = YES;
		}
		
		[self setDrawsBackground: NO];
	}
	
	return self;
}

- (id)initWithCoder:(NSCoder *) aDecoder {

	self = [super initWithCoder: aDecoder];
	
	if(self) {
		
		if([aDecoder containsValueForKey: @"themeKey"]) {
			
			self.themeKey = [aDecoder decodeObjectForKey: @"themeKey"];
		} else {
			
			self.themeKey = @"gradientTheme";
		}
		
		[self setTextColor: [[[BGThemeManager keyedManager] themeForKey: self.themeKey] textColor]];
		
		if([self drawsBackground]) {
			
			fillsBackground = YES;
		}
		
		[self setDrawsBackground: NO];
	}
	
	return self;
}

-(void)encodeWithCoder:(NSCoder *)aCoder {
	
	[super encodeWithCoder: aCoder];
	
	[aCoder encodeObject: self.themeKey forKey: @"themeKey"];
}

- (NSText *)setUpFieldEditorAttributes:(NSText *)textObj;
{
	textObj = [super setUpFieldEditorAttributes:textObj];
	NSColor *textColor = [[[BGThemeManager keyedManager] themeForKey: self.themeKey] textColor];
	[(NSTextView *)textObj setInsertionPointColor:textColor];
	return textObj;
}

-(void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	
	//Adjust Rect
	cellFrame = NSInsetRect(cellFrame, 0.5f, 0.5f);
	
	//Create Path
	NSBezierPath *path = [[NSBezierPath new] autorelease];
	
	if([self bezelStyle] == NSTextFieldRoundedBezel) {
		
		[path appendBezierPathWithArcWithCenter: NSMakePoint(cellFrame.origin.x + (cellFrame.size.height /2), cellFrame.origin.y + (cellFrame.size.height /2))
										 radius: cellFrame.size.height /2
									 startAngle: 90
									   endAngle: 270];
		
		[path appendBezierPathWithArcWithCenter: NSMakePoint(cellFrame.origin.x + (cellFrame.size.width - (cellFrame.size.height /2)), cellFrame.origin.y + (cellFrame.size.height /2))
										 radius: cellFrame.size.height /2
									 startAngle: 270
									   endAngle: 90];
		
		[path closePath];
	} else {
		
		[path appendBezierPathWithRoundedRect: cellFrame xRadius: 3.0f yRadius: 3.0f];
	}
	
	//Draw Background
	if(fillsBackground) {
		
		[[[[BGThemeManager keyedManager] themeForKey: self.themeKey] textFillColor] set];
		[path fill];
	}
	
	if([self isBezeled] || [self isBordered]) {
		
		[NSGraphicsContext saveGraphicsState];
		
		if([super showsFirstResponder] && [[[self controlView] window] isKeyWindow] && 
		   ([self focusRingType] == NSFocusRingTypeDefault ||
			[self focusRingType] == NSFocusRingTypeExterior)) {
			
			[[[[BGThemeManager keyedManager] themeForKey: self.themeKey] focusRing] set];
		}
		
		//Check State
		if([self isEnabled]) {
			
			[[[[BGThemeManager keyedManager] themeForKey: self.themeKey] strokeColor] set];
		} else {
			
			[[[[BGThemeManager keyedManager] themeForKey: self.themeKey] disabledStrokeColor] set];
		}
		
		[path setLineWidth: 1.0f];
		[path stroke];
		
		[NSGraphicsContext restoreGraphicsState];
	}
	
	//Get TextView for this editor
	NSTextView* view = (NSTextView*)[[controlView window] fieldEditor: NO forObject: controlView];
	
	//If window/app is active draw the highlight/text in active colors
	if(![self isHighlighted]) {
		
		if([view selectedRange].length > 0) {
			
			//Get Attributes of the selected text
			NSMutableDictionary *dict = [[[view selectedTextAttributes] mutableCopy] autorelease];	
			
			if([[[self controlView] window] isKeyWindow])
			{
				[dict setObject: [[[BGThemeManager keyedManager] themeForKey: self.themeKey] selectionHighlightActiveColor]
						 forKey: NSBackgroundColorAttributeName];
				
				[view setTextColor: [[[BGThemeManager keyedManager] themeForKey: self.themeKey] selectionTextActiveColor]
							 range: [view selectedRange]];
			}
			else
			{
				[dict setObject: [[[BGThemeManager keyedManager] themeForKey: self.themeKey] selectionHighlightInActiveColor]
						 forKey: NSBackgroundColorAttributeName];
				
				[view setTextColor: [[[BGThemeManager keyedManager] themeForKey: self.themeKey] selectionTextInActiveColor]
							 range: [view selectedRange]];
			}
			
			[view setSelectedTextAttributes:dict];
			dict = nil;
		} else {
			
			[self setTextColor: [[[BGThemeManager keyedManager] themeForKey: self.themeKey] textColor]];
			[view setTextColor: [[[BGThemeManager keyedManager] themeForKey: self.themeKey] textColor]];
		}
	} else {
		
		if([self isEnabled]) {

			if([self isHighlighted]) {

				if([[[self controlView] window] isKeyWindow])
				{

					[self setTextColor: [[[BGThemeManager keyedManager] themeForKey: self.themeKey] selectionTextActiveColor]];
				} else {

					[self setTextColor: [[[BGThemeManager keyedManager] themeForKey: self.themeKey] selectionTextInActiveColor]];
				}
			} else {

				[self setTextColor: [[[BGThemeManager keyedManager] themeForKey: self.themeKey] textColor]];
			}
		} else {
			
			[self setTextColor: [[[BGThemeManager keyedManager] themeForKey: self.themeKey] disabledTextColor]];
		}
	}
	
	view = nil;
	
	// Check to see if the attributed placeholder has been set or not
	//if(![self placeholderAttributedString]) {
	if(![self placeholderAttributedString] && [self placeholderString]) {
		
		//Nope lets create it
		NSDictionary *attribs = [[NSDictionary alloc] initWithObjectsAndKeys: 
								 [[[BGThemeManager keyedManager] themeForKey: self.themeKey] placeholderTextColor] , NSForegroundColorAttributeName, nil];
		
		//Set it
		[self setPlaceholderAttributedString: [[[NSAttributedString alloc] initWithString: [self placeholderString] attributes: [attribs autorelease]] autorelease]];
	}
	
	//Adjust Frame so Text Draws correctly
	switch ([self controlSize]) {
			
		case NSRegularControlSize:
			
			if([self bezelStyle] != NSTextFieldRoundedBezel) {
				
				cellFrame.origin.y += 1;
			}
			break;
			
		case NSSmallControlSize:
			
			if([self bezelStyle] == NSTextFieldRoundedBezel) {
				
				cellFrame.origin.y += 1;
			}
			break;
			
		case NSMiniControlSize:
			
			if([self bezelStyle] == NSTextFieldRoundedBezel) {
				
				cellFrame.origin.x += 1;
			}
			break;
			
		default:
			break;
	}
	
	//NSLog(@"Inside Draw With Frame");
	[self drawInteriorWithFrame: cellFrame inView: controlView];
}

-(void)drawInteriorWithFrame:(NSRect) cellFrame inView:(NSView *) controlView {

	//--Added 2009-11-17 by Alun Bestor - just-in-time addition of text shadow before we draw the text itself
	NSShadow *textShadow				= [[[BGThemeManager keyedManager] themeForKey: self.themeKey] textShadow];
	NSMutableAttributedString *value;
	if ([self attributedStringValue])	value = [[self attributedStringValue] mutableCopy];
	else								value = [[NSMutableAttributedString alloc] initWithString: [self stringValue]];
	
	if (textShadow)
	{
		[value addAttribute: NSShadowAttributeName
						 value: textShadow
						 range: NSMakeRange(0, [value length])];
	}
	else
	{
		[value removeAttribute: NSShadowAttributeName
						range: NSMakeRange(0, [value length])];
	}
	[self setAttributedStringValue: value];
	[value release];
	//--End of modifications

	[super drawInteriorWithFrame: cellFrame inView: controlView];
}

-(void)_drawKeyboardFocusRingWithFrame:(NSRect)fp8 inView:(id)fp24 {
	
}

/*-(void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent {
	
	switch ([self controlSize]) {
			
		case NSRegularControlSize:
			
			//aRect.origin.x += 1;
			//aRect.origin.y -= 1;
			break;
			
			
			
		default:
			break;
	}
	
	[super editWithFrame: aRect inView: controlView editor: textObj delegate: anObject event: theEvent];
}

-(void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength {
	
	switch ([self controlSize]) {
			
		case NSRegularControlSize:
			
			//aRect.origin.x += 1;
			//aRect.origin.y -= 1;
			break;
			
		default:
			break;
	}
	
	[super selectWithFrame: aRect inView: controlView editor: textObj delegate: anObject start: selStart length: selLength];
}*/

#pragma mark -
#pragma mark Helper Methods

-(void)dealloc {
	
	[super dealloc];
}

#pragma mark -

@end
