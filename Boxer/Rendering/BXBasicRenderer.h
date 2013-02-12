/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXBasicRenderer and its subclasses are view- and context-agnostic classes for rendering
//BXVideoFrame content using OpenGL.

//It is responsible for preparing the specified CGL context, creating textures and framebuffers,
//setting and clearing the viewport, reading frame data, and actually rendering the frames.

#import <Foundation/Foundation.h>
#import <OpenGL/OpenGL.h>

#pragma mark -
#pragma mark Error constants

enum {
    BXRendererUnsupported,    //The renderer is not supported by the current context.
};

//The domain for errors produced by BXBasicRenderer and subclasses.
extern NSString * const BXRendererErrorDomain;


#pragma mark -
#pragma mark Interface declaration

@class BXVideoFrame;
@class BXTexture2D;
@protocol BXRendererDelegate;
@interface BXBasicRenderer : NSObject
{
    CGLContextObj _context;
    __unsafe_unretained id <BXRendererDelegate> _delegate;
    
	BXVideoFrame *_currentFrame;
	CGRect _viewport;
	
    BXTexture2D *_frameTexture;
	CGSize _maxFrameTextureSize;
    
	BOOL _needsNewFrameTexture;
	BOOL _needsFrameTextureUpdate;
	
	CFAbsoluteTime _lastFrameTime;
	CFTimeInterval _renderingTime;
	CGFloat _frameRate;
    
    BOOL _needsTeardown;
}


#pragma mark -
#pragma mark Properties

//The delegate to which we will send BXRendererDelegate messages.
@property (assign) id <BXRendererDelegate> delegate;

//The context in which this renderer is running, set when the renderer is created.
//Renderers cannot be moved between contexts.
@property (readonly) CGLContextObj context;

//The current frame that will be rendered when render is called. Set using updateWithFrame:inGLContext:.
@property (retain, readonly) BXVideoFrame *currentFrame;

//The viewport in the current context into which we'll render the frame.
//Measured in device pixels.
@property (assign, nonatomic) CGRect viewport;

//The frames-per-second the renderer is producing, measured as the time between
//the last two rendered frames.
@property (assign) CGFloat frameRate;

//The time it took to render the last frame, measured as the time renderToGLContext: was called to
//the time when renderToGLContext: finished. This measures the efficiency of the rendering pipeline.
@property (assign) CFTimeInterval renderingTime;


#pragma mark -
#pragma mark Helper class methods

//Returns the maximum supported texture size for the specified type in the specified context.
+ (CGSize) maxTextureSizeForType: (GLenum)textureType inContext: (CGLContextObj)glContext; 

//Returns whether the specified context supports the specified extension.
+ (BOOL) context: (CGLContextObj)glContext supportsExtension: (const char *)featureName;


#pragma mark -
#pragma mark Initialization and context setup

//Returns a new renderer prepared for the specified context.
//Returns nil and populates outError if the renderer could not be created.
- (id) initWithContext: (CGLContextObj)glContext error: (NSError **)outError;

//Set up OpenGL assets and configure the GL context appropriately.
//Must be called before the renderer is first used.
- (void) prepareContext;

//Clean up OpenGL assets. Called automatically at dealloc, but should be called beforehand
//if possible when the renderer goes out of use.
- (void) tearDownContext;

//Returns the maximum drawable frame size in pixels.
//This is usually a limit of the maximum GL texture size.
- (CGSize) maxFrameSize;


#pragma mark -
#pragma mark Frame updates and rendering

//Sets the viewport to the specified rectangle in device pixels.
//If recalculate is YES, the renderer may adjust its rendering to suit the new size.
//If recalculate is NO, the renderer should not perform any expensive changes to the renderer setup.
//(recalculate may be NO if e.g. the view is dynamically resizing.)
- (void) setViewport: (CGRect)rect recalculate: (BOOL)recalculate;

//Called to force the renderer to update to its current viewport size.
//Intended to be used after a series of calls to setViewport:recalculate:
//with recalculate as NO.
- (void) recalculateViewport;

//Replaces the current frame with a new/updated one for rendering.
//Forces the texture contents to be reuploaded.
- (void) updateWithFrame: (BXVideoFrame *)frame;

//Whether the renderer is ready to render the current frame.
//Will be YES as long as there is a frame to render.
- (BOOL) canRender;

//Renders the frame into its GL context.
- (void) render;

@end


@protocol BXRendererDelegate <NSObject>

//Called when the renderer has completed all intermediate rendering steps
//and is ready to render to the final output surface (usually the screen.)
//The delegate can use this step to activate additional shaders or render
//to a framebuffer.
- (void) renderer: (BXBasicRenderer *)renderer willRenderTextureToDestinationContext: (BXTexture2D *)texture;
- (void) renderer: (BXBasicRenderer *)renderer didRenderTextureToDestinationContext: (BXTexture2D *)texture;

@end
