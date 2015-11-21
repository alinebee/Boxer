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
@protocol DDHidAppleRemoteDelegate;

typedef NS_ENUM(NSInteger, DDHidAppleRemoteEventIdentifier)
{
	kDDHidRemoteButtonVolume_Plus=0,
	kDDHidRemoteButtonVolume_Minus,
	kDDHidRemoteButtonMenu,
	kDDHidRemoteButtonPlay,
	kDDHidRemoteButtonRight,	
	kDDHidRemoteButtonLeft,	
	kDDHidRemoteButtonRight_Hold,	
	kDDHidRemoteButtonLeft_Hold,
	kDDHidRemoteButtonMenu_Hold,
	kDDHidRemoteButtonPlay_Sleep,
	kDDHidRemoteControl_Switched,
    kDDHidRemoteControl_Paired,
    
    kDDHidRemoteControl_Terminating = -1,
};

@interface DDHidAppleRemote : DDHidDevice
{
    NSMutableDictionary * mCookieToButtonMapping;
    NSArray * mButtonElements;
    DDHidElement * mIdElement;
    int mRemoteId;

    id<DDHidAppleRemoteDelegate> mDelegate;
}

+ (NSArray<DDHidAppleRemote*> *) allRemotes;

+ (DDHidAppleRemote *) firstRemote;

- (instancetype) initWithDevice: (io_object_t) device error: (NSError **) error_;

#pragma mark -
#pragma mark Asynchronous Notification

@property (assign) id<DDHidAppleRemoteDelegate> delegate;

- (void) addElementsToDefaultQueue;

#pragma mark -
#pragma mark Properties

@property int remoteId;

@end

@protocol DDHidAppleRemoteDelegate <NSObject>

- (void) ddhidAppleRemoteButton: (DDHidAppleRemoteEventIdentifier) buttonIdentifier
                    pressedDown: (BOOL) pressedDown;

@end
