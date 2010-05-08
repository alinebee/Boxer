/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXRenderer.h"
#import "BXGeometry.h"
#import "BXFrameBuffer.h"

@implementation BXRenderer
@synthesize viewport, maintainAspectRatio, needsDisplay;
@synthesize lastFrame;

#pragma mark -
#pragma mark Initialization and cleanup

- (void) dealloc
{
	if (glIsTexture(texture))	glDeleteTextures(1, &texture);
	if (glIsList(displayList))	glDeleteLists(displayList, 1);
	
	[self setLastFrame: nil], [lastFrame release];
	
	[super dealloc];
}


#pragma mark -
#pragma mark Framebuffer rendering

- (NSSize) maxFrameSize
{
	GLint maxSize;
	glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxSize);
	return NSMakeSize((CGFloat)maxSize, (CGFloat)maxSize);
}

- (BXFrameBuffer *) bufferForOutputSize: (NSSize)resolution atScale: (NSSize)scale
{
	return [BXFrameBuffer bufferWithResolution: resolution depth: 4 scale: scale];
}

- (void) drawFrame: (BXFrameBuffer *)frame
{
	//A new buffer is being rendered, prepare the renderer to cope with it
	if (frame != lastFrame) 
	{
		[self _prepareForFrame: frame];
		[self setLastFrame: frame];
	}
	
	glBindTexture(textureTarget, texture);
	glTexSubImage2D(textureTarget,					//Texture target
					0,								//Mipmap level
					0,								//X offset
					0,								//Y offset
					[frame resolution].width,		//width
					[frame resolution].height,		//height
					GL_BGRA,						//byte ordering
					GL_UNSIGNED_INT_8_8_8_8_REV,	//byte packing
					[frame bytes]					//pixel data
					);
	
	[self setNeedsDisplay: YES];
}

- (void) drawFrame: (BXFrameBuffer *)frame dirtyRegions: (const uint16_t *)dirtyRegions
{
	//A new buffer is being rendered, reset the renderer and then render the whole buffer anew
	if (frame != lastFrame) return [self drawFrame: frame];
	
	//Otherwise, render only the parts of the buffer that are flagged as being dirty
	if (dirtyRegions)
	{
		NSUInteger offset = 0;
		NSUInteger currentRegion = 0;
		NSUInteger height;
		void *offsetPixels;
		
		glBindTexture(textureTarget, texture);
		
		while (offset < [frame resolution].height)
		{
			//Explanation: dirtyRegions is an array describing the pixel heights of alternating dirty/clean
			//regions in the buffer.
			//e.g. (1, 5, 2, 4) means one clean line, then 5 dirty lines, then 2 clean lines, then 4 dirty lines.
			
			//On clean regions, we just increment the line offset by the number of clean lines in the region
			//and move on. On dirty regions, we draw the dirty lines from the buffer into the texture.
			
			height = dirtyRegions[currentRegion];
			
			//This is an odd row, hence a dirty line block, so write the dirty lines from it into our texture
			if (currentRegion & 1)
			{
				//Ahhh, pointer arithmetic. Determine the starting offset of the dirty region in our buffer.
				//TODO: this needs sanity-checking to make sure the offset is within expected bounds,
				//otherwise it would write arbitrary data to the texture.
				offsetPixels = [frame mutableBytes] + (offset * [frame pitch]);
				
				glTexSubImage2D(textureTarget,					//Texture target
								0,								//Mipmap level
								0,								//X offset
								offset,							//Y offset
								[frame resolution].width,		//width
								height,							//height
								GL_BGRA,						//byte ordering
								GL_UNSIGNED_INT_8_8_8_8_REV,	//byte packing
								offsetPixels					//pixel data
								);
			}
			offset += height;
			currentRegion++;
		}
		[self setNeedsDisplay: YES];
	}
}

#pragma mark -
#pragma mark OpenGL setup and output

- (void) prepareOpenGL
{
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glClearColor(0.0, 0.0, 0.0, 1.0);
	glShadeModel(GL_FLAT);
	glDisable(GL_DEPTH_TEST);
	glDisable(GL_LIGHTING);
	glDisable(GL_CULL_FACE);
	
	if (gluCheckExtension((const GLubyte*)"GL_ARB_texture_rectangle", glGetString(GL_EXTENSIONS)))
	{
		//Enable rectangular textures for a tidier texture path
		glEnable(GL_TEXTURE_RECTANGLE_ARB);
		textureTarget = GL_TEXTURE_RECTANGLE_ARB;
	}
	else
	{
		glEnable(GL_TEXTURE_2D);
		textureTarget = GL_TEXTURE_2D;
	}
	
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
}

- (void) setCanvas: (NSRect)canvasRect
{
	canvas = canvasRect;
	[self _setupViewportForFrame: [self lastFrame]];
	[self _setupFilteringForFrame: [self lastFrame]];
}

- (void) render
{
	//Avoid garbage in letterbox region by clearing every frame
	glClear(GL_COLOR_BUFFER_BIT);
	if (displayList) glCallList(displayList);
	[self setNeedsDisplay: NO];
}


@end



@implementation BXRenderer (BXRendererInternals)

- (void) _prepareForFrame: (BXFrameBuffer *)frame
{
	[self _setupViewportForFrame: frame];
	[self _setupTextureForFrame: frame];
	[self _setupDisplayListForFrame: frame];
}


- (BOOL) _shouldUseFilteringForFrame: (BXFrameBuffer *)frame
{
	if (viewport.size.width / [frame resolution].width > BXBilinearFilteringScaleCutoff) return NO;
	
	return	((NSInteger)viewport.size.width		% (NSInteger)[frame resolution].width) || 
			((NSInteger)viewport.size.height	% (NSInteger)[frame resolution].height);
}

- (void) _setupViewportForFrame: (BXFrameBuffer *)frame
{
	if (!frame)
	{
		//If there is no frame to render, fill our whole canvas
		viewport = canvas;													 
	}
	else if ([self maintainAspectRatio])
	{
		//Keep the viewport letterboxed in proportion with our output size
		NSRect outputRect = NSMakeRect(0,
									   0,
									   [frame resolution].width * [frame intendedScale].width,
									   [frame resolution].height * [frame intendedScale].height);
		viewport = fitInRect(outputRect, canvas, NSMakePoint(0.5, 0.5));
	}
	else
	{
		//Otherwise, unlock the height to let the output stretch to its new aspect ratio
		NSRect outputRect = NSMakeRect(0, 0, viewport.size.width, canvas.size.height);
		viewport = fitInRect(outputRect, canvas, NSMakePoint(0.5, 0.5));
	}
	viewport = NSIntegralRect(viewport);
	
	glViewport(viewport.origin.x,
			   viewport.origin.y,
			   viewport.size.width,
			   viewport.size.height);
}

- (void) _setupTextureForFrame: (BXFrameBuffer *)frame
{
	if (textureTarget == GL_TEXTURE_RECTANGLE_ARB)
	{
		textureSize = [frame resolution];
	}
	else
	{
		//Create a texture large enough to accommodate the buffer, whose dimensions are an even power of 2
		textureSize.width	= (CGFloat)fitToPowerOfTwo((NSInteger)[frame resolution].width);
		textureSize.height	= (CGFloat)fitToPowerOfTwo((NSInteger)[frame resolution].height);
	}
	
	//TODO: replace this check with a GL_PROXY_TEXTURE_2D call with graceful fallback
	//See glTexImage2D(3) for implementation details
	NSSize maxSize = [self maxFrameSize];
	NSAssert2(textureSize.width <= maxSize.width && textureSize.height <= maxSize.height,
			  @"Output size %@ is too large to create as a texture (maximum dimensions are %@).",
			  NSStringFromSize([frame resolution]),
			  NSStringFromSize(maxSize)
			  );
	
	//Wipe out any existing texture we have
	glDeleteTextures(1, &texture);
	glGenTextures(1, &texture);
	
	glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	glBindTexture(textureTarget, texture);
	
	//Clamp the texture to avoid wrapping, and set the filtering mode
	glTexParameteri(textureTarget, GL_TEXTURE_WRAP_S, GL_CLAMP);
	glTexParameteri(textureTarget, GL_TEXTURE_WRAP_T, GL_CLAMP);
	[self _setupFilteringForFrame: frame];
	
	//Create a new empty texture of the specified size
	glTexImage2D(textureTarget,	//Texture target
				 0,				//Mipmap level
				 GL_RGBA8,		//Internal texture format
				 (GLsizei)textureSize.width,	//Width
				 (GLsizei)textureSize.height,	//Height
				 0,								//Border (unused)
				 GL_BGRA,						//Byte ordering
				 GL_UNSIGNED_INT_8_8_8_8_REV,	//Byte packing
				 [frame bytes]					//Texture data
				 );
	
}

- (void) _setupFilteringForFrame: (BXFrameBuffer *)frame
{
	if (glIsTexture(texture))
	{
		glBindTexture(textureTarget, texture);
		
		//Apply bilinear filtering to the texture
		GLint filterMode = ([self _shouldUseFilteringForFrame: frame]) ? GL_LINEAR : GL_NEAREST;
		
		glTexParameteri(textureTarget, GL_TEXTURE_MAG_FILTER, filterMode);
		glTexParameteri(textureTarget, GL_TEXTURE_MIN_FILTER, filterMode);	
	}
}

- (void) _setupDisplayListForFrame: (BXFrameBuffer *)frame
{
	//Calculate what portion of the texture constitutes the output region
	//(this is the part of the texture that will actually be filled with the framebuffer's data)
	
	GLfloat outputX, outputY;
	if (textureTarget == GL_TEXTURE_RECTANGLE_ARB)
	{	
		//GL_TEXTURE_RECTANGLE_ARB textures use non-normalized texture coordinates
		//(e.g. 0->width instead of 0->1) because they're STUPID
		outputX = (GLfloat)textureSize.width;
		outputY = (GLfloat)textureSize.height;
	}
	else
	{
		//Regular textures use proper 0->1 coordinates
		outputX = (GLfloat)([frame resolution].width	/ textureSize.width);
		outputY = (GLfloat)([frame resolution].height	/ textureSize.height);
	}

	
	if (glIsList(displayList))
		glDeleteLists(displayList, 1);
	displayList = glGenLists(1);
	
	glNewList(displayList, GL_COMPILE);
	glBindTexture(textureTarget, texture);
	glBegin(GL_QUADS);
	
	//Now, map the output region of the texture to a surface filling the viewport
	// lower left
	glTexCoord2f(0,	outputY);		glVertex2f(-1.0f,	-1.0f);
	// lower right
	glTexCoord2f(outputX, outputY);	glVertex2f(1.0f,	-1.0f);
	// upper right
	glTexCoord2f(outputX, 0);		glVertex2f(1.0f,	1.0f);
	// upper left
	glTexCoord2f(0, 0);				glVertex2f(-1.0f,	1.0f);
	
	glEnd();
	glEndList();	
}

@end