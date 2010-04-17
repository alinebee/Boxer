/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXRenderer.h"
#import "BXGeometry.h"

@implementation BXRenderer
@synthesize viewport, outputScale, maintainAspectRatio, needsDisplay;

- (id) init
{
	if ((self = [super init]))
	{
		frameBuffer = NULL;
	}
	return self;
}
- (void) dealloc
{
	if (glIsTexture(texture))	glDeleteTextures(1, &texture);
	if (glIsList(displayList))	glDeleteLists(displayList, 1);
	if (frameBuffer)
	{
		free(frameBuffer);
		frameBuffer = NULL;
	}
	
	[super dealloc];
}


- (NSSize) maxOutputSize
{
	GLint maxSize;
	glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxSize);
	return NSMakeSize((CGFloat)maxSize, (CGFloat)maxSize);
}

- (void) prepareOpenGL
{
	glMatrixMode(GL_PROJECTION);
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

- (void *) frameBuffer
{
	return frameBuffer;
}

- (void *) setFrameBufferSize: (NSSize)size atScale: (NSSize)scale
{
	if (!NSEqualSizes(size, outputSize) || !NSEqualSizes(scale, outputScale))
	{
		outputSize = size;
		outputScale = scale;
		
		if (frameBuffer) free(frameBuffer);
		frameBuffer = malloc(outputSize.width * outputSize.height * 4);
		//TODO: fill the framebuffer with black

		//Next time one of our draw functions is called, this will resync
		//the texture, display list and viewport to fit the new output size
		rendererIsInvalid = YES;
	}
	return frameBuffer;
}

- (void) setCanvas: (NSRect)canvasRect
{
	canvas = canvasRect;
	[self _updateViewport];
	[self _updateFiltering];
}

- (void) render
{
	//Avoid garbage in letterbox region by clearing every frame
	//Man, is there a tidier way of doing this?
	glClear(GL_COLOR_BUFFER_BIT);
	if (displayList) glCallList(displayList);
	[self setNeedsDisplay: NO];
}

- (NSUInteger) pitch { return (NSUInteger)(outputSize.width * 4); }

- (void) drawPixelData: (void *)pixelData dirtyBlocks: (const uint16_t *)dirtyBlocks
{
	if (dirtyBlocks)
	{
		if (rendererIsInvalid) [self _updateRenderer];
		
		NSUInteger offset = 0, i = 0;
		NSUInteger height, pitch = [self pitch];
		void *offsetPixels;
		
		glBindTexture(textureTarget, texture);
		
		while (offset < outputSize.height)
		{
			//Explanation: dirtyBlocks is an array describing the heights of alternating blocks of dirty/clean lines.
			//e.g. (1, 5, 2, 4) means one clean line, then 5 dirty lines, then 2 clean lines, then 4 dirty lines.
			
			//On clean blocks, we just increment the line offset by the number of clean lines in the block and move on.
			//On dirty blocks, we draw the dirty lines from the pixel data into the texture.
			
			height = dirtyBlocks[i];
			
			//This is an odd row, hence a dirty line block, so write the dirty lines from it into our texture
			if (i & 1)
			{
				//Ahhh, pointer arithmetic. Determine the starting offset of the dirty line block in our pixel data.
				//TODO: this needs sanity-checking to make sure the offset is within expected bounds,
				//otherwise it would write arbitrary data to the texture.
				offsetPixels = frameBuffer + (offset * pitch);
				
				glTexSubImage2D(textureTarget,		//Texture target
								0,					//Mipmap level
								0,					//X offset
								offset,				//Y offset
								outputSize.width,	//width
								height,				//height
								GL_BGRA,						//byte ordering
								GL_UNSIGNED_INT_8_8_8_8_REV,	//byte packing
								offsetPixels		//pixel data
								);
				
			}
			offset += height;
			i++;
		}
		[self setNeedsDisplay: YES];
	}
}

- (void) drawPixelData: (void *)pixelData
{
	if (rendererIsInvalid) [self _updateRenderer];
	
	glBindTexture(textureTarget, texture);
	glTexSubImage2D(textureTarget,		//Texture target
					0,					//Mipmap level
					0,					//X offset
					0,					//Y offset
					outputSize.width,	//width
					outputSize.height,	//height
					GL_BGRA,						//byte ordering
					GL_UNSIGNED_INT_8_8_8_8_REV,	//byte packing
					frameBuffer			//pixel data
					);
	[self setNeedsDisplay: YES];
}

@end



@implementation BXRenderer (BXRendererInternals)

- (void) _updateRenderer
{
	[self _updateViewport];
	[self _createTexture];
	[self _createDisplayList];
	
	rendererIsInvalid = NO;
}


- (BOOL) _shouldUseFiltering
{	
	if (viewport.size.width / outputSize.width > BXBilinearFilteringScaleCutoff) return NO;
	
	return	((NSInteger)viewport.size.width		% (NSInteger)outputSize.width) || 
			((NSInteger)viewport.size.height	% (NSInteger)outputSize.height);
}

- (void) _updateViewport
{
	if (NSEqualSizes(outputSize, NSZeroSize) || NSEqualSizes(outputScale, NSZeroSize))
	{
		//If no frame has been rendered yet, fill the whole canvas
		viewport = canvas;													 
	}
	else if ([self maintainAspectRatio])
	{
		//Keep the viewport letterboxed in proportion with our output size
		NSRect outputRect = NSMakeRect(0, 0, outputSize.width * outputScale.width, outputSize.height * outputScale.height);
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
	
	glClear(GL_COLOR_BUFFER_BIT);
}

- (void) _createTexture
{
	if (textureTarget == GL_TEXTURE_RECTANGLE_ARB)
	{
		textureSize = outputSize;
	}
	else
	{
		//Create a texture large enough to accommodate the output size, whose dimensions are an even power of 2
		textureSize.width	= (CGFloat)fitToPowerOfTwo((NSInteger)outputSize.width);
		textureSize.height	= (CGFloat)fitToPowerOfTwo((NSInteger)outputSize.height);
	}
	
	//TODO: replace this check with a GL_PROXY_TEXTURE_2D call with graceful fallback
	//See glTexImage2D(3) for implementation details
	NSSize maxSize = [self maxOutputSize];
	NSAssert2(textureSize.width <= maxSize.width && textureSize.height <= maxSize.height,
			  @"Output size %@ is too large to create as a texture (maximum dimensions are %@).",
			  NSStringFromSize(outputSize),
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
	[self _updateFiltering];
	
	
	//Create a new empty texture of the specified size
	glTexImage2D(textureTarget,	//Texture target
				 0,				//Mipmap level
				 GL_RGBA8,		//Internal texture format
				 (GLsizei)textureSize.width,	//Width
				 (GLsizei)textureSize.height,	//Height
				 0,								//Border (unused)
				 GL_BGRA,						//Byte ordering
				 GL_UNSIGNED_INT_8_8_8_8_REV,	//Byte packing
				 frameBuffer					//Texture data
				 );
	
}

- (void) _updateFiltering
{
	if (glIsTexture(texture))
	{
		glBindTexture(textureTarget, texture);
		
		//Apply bilinear filtering to the texture
		GLint filterMode = ([self _shouldUseFiltering]) ? GL_LINEAR : GL_NEAREST;
		
		glTexParameteri(textureTarget, GL_TEXTURE_MAG_FILTER, filterMode);
		glTexParameteri(textureTarget, GL_TEXTURE_MIN_FILTER, filterMode);	
	}
}

- (void) _createDisplayList
{
	//Calculate what portion of the texture constitutes the output region
	//(this is the part of the texture that will actually be filled with framebuffer data)
	
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
		outputX = (GLfloat)(outputSize.width	/ textureSize.width);
		outputY = (GLfloat)(outputSize.height	/ textureSize.height);
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