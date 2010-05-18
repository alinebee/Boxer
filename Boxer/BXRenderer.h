/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXRenderer class description goes here.

#import <Foundation/Foundation.h>
#import <OpenGL/OpenGL.h>

@class BXFrameBuffer;

@interface BXRenderer : NSObject
{
	BXFrameBuffer *currentFrame;

	BOOL supportsFBO;
	BOOL useScalingBuffer;
	
	CGRect canvas;
	
	GLuint frameTexture;
	GLuint scalingBufferTexture;
	GLuint scalingBuffer;
	CGSize scalingBufferSize;
	
	CGSize maxTextureSize;
	CGSize maxScalingBufferSize;
	
	BOOL needsNewFrameTexture;
	BOOL needsFrameTextureUpdate;
	BOOL recalculateScalingBuffer;
	
	NSTimeInterval lastFrameTime;
	NSTimeInterval renderingTime;
	CGFloat frameRate;	
}
@property (retain) BXFrameBuffer *currentFrame;
@property (assign) CGFloat frameRate;
@property (assign) CGRect canvas;
@property (assign) NSTimeInterval renderingTime;

- (void) updateWithFrame: (BXFrameBuffer *)frame;

- (void) prepareForGLContext:	(CGLContextObj)glContext;
- (void) tearDownGLContext:		(CGLContextObj)glContext;
- (BOOL) canRenderToGLContext:	(CGLContextObj)glContext;
- (void) renderToGLContext:		(CGLContextObj)glContext;
@end