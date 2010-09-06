/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXGeometry provides various functions for manipulating NSPoints, NSSizes and NSRects.


//The C brace is needed when including this header from an Objective C++ file
#if __cplusplus
extern "C" {
#endif

	#import <Foundation/Foundation.h>

	//Returns the nearest power of two that can accommodate the specified value
	NSInteger fitToPowerOfTwo(NSInteger value);

	//Returns the aspect ratio (width / height) for size. This will be 0 if either dimension was 0.
	CGFloat aspectRatioOfSize(NSSize size);

	//Returns whether the inner size is equal to or less than the outer size.
	//An analogue for NSContainsRect.
	BOOL sizeFitsWithinSize(NSSize innerSize, NSSize outerSize);

	//Returns innerSize scaled to fit exactly within outerSize while preserving aspect ratio.
	NSSize sizeToFitSize(NSSize innerSize, NSSize outerSize);

	//Same as sizeToFitSize, but will return innerSize without scaling up if it already fits within outerSize.
	NSSize constrainToFitSize(NSSize innerSize, NSSize outerSize);

	//Resize an NSRect to the target NSSize, using a relative anchor point: 
	//{0,0} is bottom left, {1,1} is top right, {0.5,0.5} is center.
	NSRect resizeRectFromPoint(NSRect theRect, NSSize newSize, NSPoint anchor);

	//Get the relative position ({0,0}, {1,1} etc.) of an NSPoint origin, relative to the specified NSRect.
	NSPoint pointRelativeToRect(NSPoint thePoint, NSRect theRect);

	//Align innerRect within outerRect relative to the specified anchor point: 
	//{0,0} is bottom left, {1,1} is top right, {0.5,0.5} is center.
	NSRect alignInRectWithAnchor(NSRect innerRect, NSRect outerRect, NSPoint anchor);

	//Center innerRect within outerRect. Equivalent to alignRectInRectWithAnchor of {0.5, 0.5}.
	NSRect centerInRect(NSRect innerRect, NSRect outerRect);
		
	//Proportionally resize innerRect to fit inside outerRect, relative to the specified anchor point.
	NSRect fitInRect(NSRect innerRect, NSRect outerRect, NSPoint anchor);
	
	//Same as fitInRect, but will return alignInRectWithAnchor instead if innerRect already fits within outerRect.
	NSRect constrainToRect(NSRect innerRect, NSRect outerRect, NSPoint anchor);
	
	
	//Clamp the specified point so that it fits within the specified rect.
	NSPoint clampPointToRect(NSPoint point, NSRect rect);
	
	//Calculate the delta between two points.
	NSPoint deltaFromPointToPoint(NSPoint pointA, NSPoint pointB);
	
	//Add/remove the specified delta from the specified starting point.
	NSPoint pointWithDelta(NSPoint point, NSPoint delta);
	NSPoint pointWithoutDelta(NSPoint point, NSPoint delta);
	
	
	//CG implementations of the above functions.
	BOOL BXCGSizeFitsWithinSize(CGSize innerSize, CGSize outerSize);
	
	CGSize BXCGSizeToFitSize(CGSize innerSize, CGSize outerSize);
	
	CGSize BXCGSmallerSize(CGSize size1, CGSize size2);

	CGSize BXCGLargerSize(CGSize size1, CGSize size2);

#if __cplusplus
} //Extern C
#endif
