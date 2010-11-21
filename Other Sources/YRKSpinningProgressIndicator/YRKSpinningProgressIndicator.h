//
//  YRKSpinningProgressIndicator.h
//
//  Copyright 2009 Kelan Champagne. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface YRKSpinningProgressIndicator : NSView {
    int _position;
    int _numFins;
    
    BOOL _isAnimating;
    NSTimer *_animationTimer;
	NSThread *_animationThread;
    
    NSColor *_foreColor;
    NSColor *_backColor;
    BOOL _drawBackground;
    
    NSTimer *_fadeOutAnimationTimer;
    BOOL _isFadingOut;
    
    // For determinate mode
    BOOL _isIndeterminate;
    double _currentValue;
    double _maxValue;
    
    BOOL _usesThreadedAnimation;
}

//A property for bindings. Calls stopAnimation/startAnimation when set.
@property (assign, getter=isAnimating) BOOL animating;

@property (assign, getter=isIndeterminate) BOOL indeterminate;
@property (copy) NSColor *color;
@property (copy) NSColor *backgroundColor;
@property (assign) BOOL drawsBackground;
@property (assign) double doubleValue;
@property (assign) double maxValue;
@property (assign) BOOL usesThreadedAnimation;

- (void)stopAnimation: (id)sender;
- (void)startAnimation: (id)sender;

@end
