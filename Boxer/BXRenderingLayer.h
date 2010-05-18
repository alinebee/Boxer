//
//  BXRenderingLayer.h
//  Boxer
//
//  Created by Alun on 10/05/2010.
//  Copyright 2010 Alun Bestor and contributors. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

@class BXRenderer;

@interface BXRenderingLayer : CAOpenGLLayer
{
	BXRenderer *renderer;
}
@property (retain) BXRenderer *renderer;

@end