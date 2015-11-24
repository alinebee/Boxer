/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */

//The ADBWindowDimensions category adds additional window sizing options to NSWindow,
//to resize relative to the entire screen or to a point on screen.

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSWindow (ADBWindowDimensions)

/// Returns the window at the specified point (in screen coordinates) belonging
/// to this application. Will return nil if there is no window at that point,
/// or a window belonging to another app.
+ (nullable NSWindow *) windowAtPoint: (NSPoint)screenPoint;


/// Resize the window relative to an anchor point.
/// anchorPoint is expressed as a fraction of the window size:
/// e.g. {0, 0} is bottom left, {1, 1} is top right, {0.5, 0.5} is the window's center
- (void) setFrameSize: (NSSize)newSize
           anchoredOn: (NSPoint)anchorPoint
              display: (BOOL)displayViews
              animate: (BOOL)performAnimation;
			
/// Resizes the window towards the center of the screen, avoiding the edges of the screen.
- (void) setFrameSizeKeepingWithinScreen: (NSSize)newSize
                                 display: (BOOL)displayViews
                                 animate: (BOOL)performAnimation;

/// Constrains the rectangle to fit within the available screen real estate,
/// without resizing it: a more rigorous version of NSWindow contrainFrameRect:toScreen:
/// Prioritises left screen edge over right and top edge over bottom,
/// to ensure that the titlebar and window controls are visible.
- (NSRect) fullyConstrainFrameRect: (NSRect)theRect toScreen: (NSScreen *)theScreen;

/// Returns a new window frame rect calculated to fit the specified content size.
/// Resizing is relative to an earlier window frame, using the specified relative anchor point.
/// (See note above for relative anchor points.)
- (NSRect) frameRectForContentSize: (NSSize)contentSize
                   relativeToFrame: (NSRect)windowFrame
                        anchoredAt: (NSPoint)anchor;
@end

NS_ASSUME_NONNULL_END
