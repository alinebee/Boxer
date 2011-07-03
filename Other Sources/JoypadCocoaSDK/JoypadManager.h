//
//  JoypadManager.h
//  Joypad SDK
//
//  Created by Lou Zell on 2/26/11.
//  Copyright 2011 Hazelmade. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JoypadConstants.h"

@class JoypadDevice;
@class JoypadControllerLayout;

#pragma mark -
#if TARGET_OS_IPHONE || (MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5)
@interface JoypadManager : NSObject<NSNetServiceBrowserDelegate>
#else
@interface JoypadManager : NSObject
#endif
{
  NSNetServiceBrowser *serviceBrowser;
  NSMutableArray *devices;
  NSMutableArray *connectedDevices;
  id delegate;
  JoyControllerIdentifier layoutIdentifier;
  JoypadControllerLayout *controllerLayout;
}

#pragma mark Public API
-(void)startFindingDevices;
-(void)stopFindingDevices;
-(void)connectToDevice:(JoypadDevice *)device asPlayer:(unsigned int)player;
-(void)connectToDeviceAtIp:(NSString *)ipAddr port:(UInt16)port asPlayer:(unsigned int)player;
-(void)usePreInstalledLayout:(JoyControllerIdentifier)layoutId;
-(void)useCustomLayout:(JoypadControllerLayout *)layout;

#pragma mark JoypadDevice Called Actions
-(void)deviceDidConnect:(JoypadDevice *)device;
-(void)deviceDidDisconnect:(JoypadDevice *)device;

#pragma mark Getters
-(id)delegate;
-(JoyControllerIdentifier)layoutIdentifier;
-(JoypadControllerLayout *)controllerLayout;
-(NSMutableArray *)connectedDevices;

#pragma mark Setters
-(void)setDelegate:(id)aDelegate;
-(void)setControllerLayout:(JoypadControllerLayout *)layout;
@end

#pragma mark -
@interface NSObject (JoypadManagerDelegate)

-(void)joypadManager:(JoypadManager *)manager didFindDevice:(JoypadDevice *)device previouslyConnected:(BOOL)prev;
-(void)joypadManager:(JoypadManager *)manager didLoseDevice:(JoypadDevice *)device;
-(void)joypadManager:(JoypadManager *)manager deviceDidConnect:(JoypadDevice *)device player:(unsigned int)player;
-(void)joypadManager:(JoypadManager *)manager deviceDidDisconnect:(JoypadDevice *)device player:(unsigned int)player;

@end

