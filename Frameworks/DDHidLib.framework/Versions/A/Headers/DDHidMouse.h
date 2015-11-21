/*
 * Copyright (c) 2007 Dave Dribin
 * 
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import <Cocoa/Cocoa.h>
#import "DDHidDevice.h"

@class DDHidElement;
@class DDHidQueue;

@protocol DDHidMouseDelegate;

@interface DDHidMouse : DDHidDevice
{
    DDHidElement * mXElement;
    DDHidElement * mYElement;
    DDHidElement * mWheelElement;
    NSMutableArray * mButtonElements;
    
    id<DDHidMouseDelegate> mDelegate;
}

+ (NSArray<DDHidMouse*> *) allMice;

- (instancetype) initWithDevice: (io_object_t) device error: (NSError **) error_;

#pragma mark -
#pragma mark Mouse Elements

@property (readonly, retain) DDHidElement *xElement;
@property (readonly, retain) DDHidElement *yElement;
@property (readonly, retain) DDHidElement *wheelElement;

- (NSArray<DDHidElement*> *) buttonElements;

- (NSInteger) numberOfButtons;

- (void) addElementsToQueue: (DDHidQueue *) queue;

#pragma mark -
#pragma mark Asynchronous Notification

@property (assign) id<DDHidMouseDelegate> delegate;

- (void) addElementsToDefaultQueue;

@end

@protocol DDHidMouseDelegate <NSObject>

@optional
- (void) ddhidMouse: (DDHidMouse *) mouse xChanged: (SInt32) deltaX;
- (void) ddhidMouse: (DDHidMouse *) mouse yChanged: (SInt32) deltaY;
- (void) ddhidMouse: (DDHidMouse *) mouse wheelChanged: (SInt32) deltaWheel;
- (void) ddhidMouse: (DDHidMouse *) mouse buttonDown: (unsigned) buttonNumber;
- (void) ddhidMouse: (DDHidMouse *) mouse buttonUp: (unsigned) buttonNumber;

@end

