/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXHUDControls defines a set of NSControl and NSCell subclasses
//for use in HUD-style translucent black windows.

#import <BGHUDAppKit/BGHUDAppKit.h>
#import "BXScroller.h"
#import "BXTemplateImageCell.h"
#import "BXHUDSegmentedCell.h"


//BGHUDAppKit control subclasses hardcoded to use BXBlueTheme.
//These are for use in XCode 4+, which does not support the IB
//plugin that BGHUDAppKit relies on for defining themes.

@interface BXHUDLabel : BGHUDLabel
@end

@interface BXHUDButtonCell : BGHUDButtonCell
@end

@interface BXHUDCheckboxCell : BXHUDButtonCell
@end

@interface BXHUDSliderCell : BGHUDSliderCell
@end

@interface BXHUDPopUpButtonCell : BGHUDPopUpButtonCell
@end


//A translucent white progress indicator designed for HUD panels.
@interface BXHUDProgressIndicator: NSProgressIndicator
{
    NSTimer *animationTimer;
}

//Draw methods called from drawRect:
- (NSBezierPath *) stripePathForFrame: (NSRect)frame
                        animationTime: (NSTimeInterval)timeInterval;
- (void) drawProgressInRect: (NSRect)dirtyRect;
- (void) drawIndeterminateProgressInRect: (NSRect)dirtyRect;
- (void) drawSlotInRect: (NSRect)dirtyRect;

//Called each time the animation timer fires.
- (void) performAnimation: (NSTimer *)timer;

@end


//A shadowed white level indicator designed for bezel notifications.
@interface BXHUDLevelIndicatorCell : NSLevelIndicatorCell
{
	NSColor *indicatorColor;
	NSShadow *indicatorShadow;
}

@property (copy, nonatomic) NSColor *indicatorColor;
@property (copy, nonatomic) NSShadow *indicatorShadow;

//Returns the height used for the level indicator at the specified control size
+ (CGFloat) heightForControlSize: (NSControlSize)size;

@end


//A custom view used for drawing a rounded translucent bezel background.
@interface BXBezelView: NSView
@end
