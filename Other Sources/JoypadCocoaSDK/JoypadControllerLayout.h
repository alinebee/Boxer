//
//  JoypadControllerLayout.h
//  Joypad Common SDK
//
//  Created by Lou Zell on 3/14/11.
//  Copyright 2011 Hazelmade. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "JoypadConstants.h"

@interface JoypadControllerLayout : NSObject {
  NSMutableArray *inputComponentTemplates;
  NSString *name;
  unsigned int numBitsUsed;
}

#pragma mark Actions
-(void)addButtonWithFrame:(CGRect)rect identifier:(JoyInputIdentifier)inputId;
-(void)addButtonWithFrame:(CGRect)rect label:(NSString *)label fontSize:(unsigned int)fontSize shape:(JoyButtonShape)shape color:(JoyButtonColor)color identifier:(JoyInputIdentifier)inputId;

// Adds a dpad with the specified frame and automatically places
// the dpad origin at the center of the frame. This is the quickest way to drop
// a dpad down.  However, we recommend using -addDpadWithFrame:dpadOrigin:identifier,
// described next.
-(void)addDpadWithFrame:(CGRect)rect identifier:(JoyInputIdentifier)inputId;

// Enables you to drop a dpad in with an origin that is not in the center of the frame.
// This is useful for giving your user more play around the edge of the dpad.  For example,
// if you specified an origin and frame as follows, you would give your users a larger
// hit area to the right side of the dpad: 
//
//    +----------+
//    |          |
//    |   *      |
//    |          |
//    +----------+
//
// Users tend to have a good grasp of where the edge of the device is, so the area to the
// left of the dpad can be less than the right.  The dpad image itself is 180x180.  We find 
// that extending the touch area past the edge of the dpad on the top, right, and bottom is
// very beneficial to the experience. As a starting point, try: 
//  
//   [customLayout addDpadWithFrame:CGRectMake(0, 44, 280, 256) dpadOrigin:CGPointMake(110, 182) identifier:kJoyInputDpad1];
//
// These are the dimensions that we use for the pre-installed controllers.
-(void)addDpadWithFrame:(CGRect)rect dpadOrigin:(CGPoint)origin identifier:(JoyInputIdentifier)inputId;

-(void)addAccelerometer;
-(void)addAnalogStickWithFrame:(CGRect)rect identifier:(JoyInputIdentifier)inputId;

#pragma mark RPC Encoding
-(NSArray *)propertiesToEncode;

#pragma mark Getters
-(NSMutableArray *)inputComponentTemplates;
-(NSString *)name;

#pragma mark Setters
-(void)setName:(NSString *)layoutName;

#pragma mark Legacy
+(JoypadControllerLayout *)anyPreInstalled;

@end
