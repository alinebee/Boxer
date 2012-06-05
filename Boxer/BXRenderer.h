/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXRenderer is a view- and context-agnostic class for rendering frame content using OpenGL.
//It is responsible for preparing a specified CGL context, creating textures and framebuffers,
//managing the viewport, reading frame data, and actually rendering the frames.

//BXRenderer does not own or retain the OpenGL context, and tries to leave the context in the
//state in which it found it after every frame (as is required for CAOpenGLLayer-based drawing.)

//In future, some of BXRenderer's rendering functionality will be moved off into rendering-style
//child objects. These will request textures and framebuffers from BXRenderer, and render into
//them using their own specific shaders and rendering approach.

#import <Foundation/Foundation.h>
#import <OpenGL/OpenGL.h>

@class BXVideoFrame;
@class BXShader;
@class BXTexture2D;

@interface BXRenderer : NSObject
{
    CGLContextObj _context;
    
	BXVideoFrame *_currentFrame;
	NSArray *_shaders;
	
	BOOL _supportsFBO;
	BOOL _useScalingBuffer;
	
	CGRect _canvas;
	BOOL _maintainsAspectRatio;
	
    BXTexture2D *_frameTexture;
    BXTexture2D *_scalingBufferTexture;
	GLuint _scalingBuffer;
	
	CGSize _maxTextureSize;
	CGSize _maxScalingBufferSize;
    
	BOOL _needsNewFrameTexture;
	BOOL _needsFrameTextureUpdate;
	BOOL _recalculateScalingBuffer;
	
	CFAbsoluteTime _lastFrameTime;
	CFTimeInterval _renderingTime;
	CGFloat _frameRate;
}

#pragma mark -
#pragma mark Properties

//The context in which this renderer is running, set when the renderer is created.
//Renderers cannot be moved between contexts.
@property (readonly) CGLContextObj context;

//The current frame that will be rendered when render is called. Set using updateWithFrame:inGLContext:.
@property (retain, readonly) BXVideoFrame *currentFrame;

//An array of BXBSNESShaders that will be applied in order when rendering the current frame.
@property (retain) NSArray *shaders;

//The bounds of the view/layer in which we are rendering.
//Set by the view, and used for viewport and scaling calculations.
@property (assign, nonatomic) CGRect canvas;

//Whether to adjust the GL viewport to match the aspect ratio of the current frame.
//If NO, the GL viewport will fill the entire canvas.
@property (assign, nonatomic) BOOL maintainsAspectRatio;


//The frames-per-second the renderer is producing, measured as the time between
//the last two rendered frames.
@property (assign) CGFloat frameRate;

//The time it took to render the last frame, measured as the time renderToGLContext: was called to
//the time when renderToGLContext: finished. This measures the efficiency of the rendering pipeline.
@property (assign) CFTimeInterval renderingTime;


#pragma mark -
#pragma mark Methods

//Returns a new renderer prepared for the specified context.
- (id) initWithGLContext: (CGLContextObj)glContext;

//Replaces the current frame with a new/updated one for rendering.
- (void) updateWithFrame: (BXVideoFrame *)frame;

//Returns the maximum drawable frame size. This is usually a limit of the maximum GL texture size.
- (CGSize) maxFrameSize;

//Returns the rectangular region of the current canvas that the specified frame would be drawn into.
- (CGRect) viewportForFrame: (BXVideoFrame *)frame;

//Whether the renderer is ready to render the current frame.
//Will be YES as long as there is a frame to render.
- (BOOL) canRender;

//Renders the frame into its GL context.
- (void) render;

//Flushes the OpenGL framebuffer in the renderer's context.
- (void) flush;

@end
