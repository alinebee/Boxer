/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXRenderer.h"
#import "BXGeometry.h"

@implementation BXRenderer
@synthesize outputSize, maintainAspectRatio;

- (void) dealloc
{
	if (glIsTexture(texture))	glDeleteTextures(1, &texture);
	if (glIsList(displayList))	glDeleteLists(displayList, 1);
	
	[super dealloc];
}

- (NSOpenGLContext *) context
{
	return [NSOpenGLContext currentContext];
}

- (void) prepareForOutputSize: (NSSize)size atScale: (NSSize)scale
{
	outputSize = size;
	outputScale = scale;
	
	[self _prepareOpenGL];
	[self _createTexture];
	[self _createDisplayList];
}

- (void) setViewportRect: (NSRect)viewportRect
{
	NSRect outputRect, renderRect;
	if ([self maintainAspectRatio])
	{
		//Keep the rendering area letterboxed in proportion with our output size
		outputRect = NSMakeRect(0, 0, outputSize.width * outputScale.width, outputSize.height * outputScale.height);
		renderRect = fitInRect(outputRect, viewportRect, NSMakePoint(0.5, 0.5));
	}
	else
	{
		renderRect = viewportRect;
	}

	viewportSize = renderRect.size;
	glViewport(renderRect.origin.x,
			   renderRect.origin.y,
			   renderRect.size.width,
			   renderRect.size.height);

	[self clear];
	[self _updateFiltering];
}

- (void) render
{
	glCallList(displayList);
}

- (void) clear
{
	glClearColor(0.0, 0.0, 0.0, 1.0);
	glClear(GL_COLOR_BUFFER_BIT);
}

- (void) _prepareOpenGL
{
	glMatrixMode(GL_PROJECTION);
	
	glShadeModel(GL_FLAT);
	glDisable(GL_DEPTH_TEST);
	glDisable(GL_LIGHTING);
	glDisable(GL_CULL_FACE);
	glEnable(GL_TEXTURE_2D);
	
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
}

- (void) _createTexture
{
	//Create a texture large enough to accommodate the output size, whose dimensions are an even power of 2 
	textureSize.width	= (CGFloat)fitToPowerOfTwo((NSInteger)outputSize.width);
	textureSize.height	= (CGFloat)fitToPowerOfTwo((NSInteger)outputSize.height);
	
	//TODO: replace this check with a GL_PROXY_TEXTURE_2D call with graceful fallback
	//See glTexImage2D(3) for implementation details
	GLint maxSize;
	glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxSize);
	NSAssert1(textureSize.width <= maxSize && textureSize.height <= maxSize,
			  @"Output size %@ is too large to create as a texture.", NSStringFromSize(outputSize));
	
	//Wipe out any existing texture we have
	glDeleteTextures(1, &texture);
	glGenTextures(1, &texture);
	glBindTexture(GL_TEXTURE_2D, texture);
	
	//Clamp the texture to avoid wrapping
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);
	
	[self _updateFiltering];
	//Create a new empty texture of the specified size
	//TODO: fill this with black, as to start with it's filled with leftover garbage data from arbitrary memory space
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, textureSize.width, textureSize.height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, 0);	
}

- (void) _updateFiltering
{
	if (glIsTexture(texture))
	{
		glBindTexture(GL_TEXTURE_2D, texture);

		//Apply bilinear filtering to the texture
		GLint filterMode = ([self _shouldUseFiltering]) ? GL_LINEAR : GL_NEAREST;
		
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, filterMode);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, filterMode);	
	}
}

- (BOOL) _shouldUseFiltering
{
	return	((NSInteger)viewportSize.width	% (NSInteger)outputSize.width) || 
			((NSInteger)viewportSize.height	% (NSInteger)outputSize.height);
}

- (void) _createDisplayList
{
	//Calculate what portion of the texture constitutes the output region
	//(this is the part of the texture that will actually be filled with framebuffer data)
	GLfloat outputX = (GLfloat)(outputSize.width	/ textureSize.width);
	GLfloat outputY = (GLfloat)(outputSize.height	/ textureSize.height);
	
	if (glIsList(displayList))
		glDeleteLists(displayList, 1);
	displayList = glGenLists(1);
	
	glNewList(displayList, GL_COMPILE);
	glBindTexture(GL_TEXTURE_2D, texture);
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

- (NSUInteger) _pitch { return (NSUInteger)(outputSize.width * 4); }

- (void) _drawPixelData: (void *)pixelData dirtyLines: (const uint16_t *)dirtyLines
{
	if (dirtyLines)
	{
		NSUInteger offset = 0, i = 0;
		NSUInteger height, pitch = [self _pitch];
		void *offsetPixels;
		
		glBindTexture(GL_TEXTURE_2D, texture);
		
		while (offset < outputSize.height)
		{
			//Explanation: dirtyLines is an array describing the heights of alternating blocks of dirty/clean lines.
			//e.g. (1, 5, 2, 4) means one clean line, then 5 dirty lines, then 2 clean lines, then 4 dirty lines.
			
			//On clean blocks, we just increment the line offset by the number of clean lines in the block and move on.
			//On dirty blocks, we draw the dirty lines from the pixel data into the texture.
			
			height = dirtyLines[i];
			
			//This is an odd row, hence a dirty line block, so write the dirty lines from it into our texture
			if (i & 1)
			{
				//Ahhh, pointer arithmetic. Determine the starting offset of the dirty line block in our pixel data.
				//TODO: this needs sanity-checking to make sure the offset is within expected bounds,
				//otherwise it would write arbitrary data to the texture.
				offsetPixels = pixelData + (offset * pitch);
				
				glTexSubImage2D(GL_TEXTURE_2D,		//Texture target
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
	}
}

- (void) _drawPixelData: (void *)pixelData
{
	glBindTexture(GL_TEXTURE_2D, texture);
	glTexSubImage2D(GL_TEXTURE_2D,		//Texture target
					0,					//Mipmap level
					0,					//X offset
					0,					//Y offset
					outputSize.width,	//width
					outputSize.height,	//height
					GL_BGRA,						//byte ordering
					GL_UNSIGNED_INT_8_8_8_8_REV,	//byte packing
					pixelData			//pixel data
					);
}
@end