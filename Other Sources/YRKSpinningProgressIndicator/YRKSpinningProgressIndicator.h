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
    CGFloat _lineWidth;
    CGFloat _lineStartOffset;
    CGFloat _lineEndOffset;
    
    BOOL _usesThreadedAnimation;
}

//A property for bindings. Calls stopAnimation/startAnimation when set.
@property (nonatomic, assign, getter=isAnimating) BOOL animating;

@property (nonatomic, assign, getter=isIndeterminate) BOOL indeterminate;
@property (nonatomic, copy) NSColor *color;
@property (nonatomic, copy) NSColor *backgroundColor;
@property (nonatomic, assign) BOOL drawsBackground;
@property (nonatomic, assign) double doubleValue;
@property (nonatomic, assign) double maxValue;
@property (nonatomic, assign) BOOL usesThreadedAnimation;
@property (nonatomic, assign) CGFloat lineWidth;
@property (nonatomic, assign) CGFloat lineStartOffset;
@property (nonatomic, assign) CGFloat lineEndOffset;

- (void)stopAnimation: (id)sender;
- (void)startAnimation: (id)sender;

@end
