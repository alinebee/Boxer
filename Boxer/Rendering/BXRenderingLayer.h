/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXRenderingLayer is a CAOpenGLLayer subclass which hosts a BXRenderer object for rendering
//a frame into the layer. It does very little actual work itself, mostly just passing API calls
//to BXRenderer.

#import <QuartzCore/QuartzCore.h>

@class BXRenderer;

@interface BXRenderingLayer : CAOpenGLLayer
{
	BXRenderer *renderer;
}
@property (retain) BXRenderer *renderer;

@end
