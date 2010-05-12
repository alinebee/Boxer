//---------------------------------------------------------------------------------
//
//	File: Shader.m
//
//  Abstract: Rudimentary class to instantiate a shader object
//            NOTE: This class does not validate the program object
// 			 
//  Disclaimer: IMPORTANT:  This Apple software is supplied to you by
//  Inc. ("Apple") in consideration of your agreement to the following terms, 
//  and your use, installation, modification or redistribution of this Apple 
//  software constitutes acceptance of these terms.  If you do not agree with 
//  these terms, please do not use, install, modify or redistribute this 
//  Apple software.
//  
//  In consideration of your agreement to abide by the following terms, and
//  subject to these terms, Apple grants you a personal, non-exclusive
//  license, under Apple's copyrights in this original Apple software (the
//  "Apple Software"), to use, reproduce, modify and redistribute the Apple
//  Software, with or without modifications, in source and/or binary forms;
//  provided that if you redistribute the Apple Software in its entirety and
//  without modifications, you must retain this notice and the following
//  text and disclaimers in all such redistributions of the Apple Software. 
//  Neither the name, trademarks, service marks or logos of Apple Inc. may 
//  be used to endorse or promote products derived from the Apple Software 
//  without specific prior written permission from Apple.  Except as 
//  expressly stated in this notice, no other rights or licenses, express
//  or implied, are granted by Apple herein, including but not limited to
//  any patent rights that may be infringed by your derivative works or by
//  other works in which the Apple Software may be incorporated.
//  
//  The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
//  MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
//  THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
//  FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
//  OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
//  
//  IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
//  OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
//  MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
//  AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
//  STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
// 
//  Copyright (c) 2008 Apple Inc., All rights reserved.
//
//---------------------------------------------------------------------------------

//---------------------------------------------------------------------------------

#import "Shader.h"

//---------------------------------------------------------------------------------

//---------------------------------------------------------------------------------

#pragma mark -- Compiling shaders & linking a program object --

//---------------------------------------------------------------------------------

static GLhandleARB LoadShader(GLenum theShaderType, 
							  const GLcharARB **theShader, 
							  GLint *theShaderCompiled) 
{
	GLhandleARB shaderObject = NULL;
	
	if( theShader != NULL ) 
	{
		GLint infoLogLength = 0;
		
		shaderObject = glCreateShaderObjectARB(theShaderType);
		
		glShaderSourceARB(shaderObject, 1, theShader, NULL);
		glCompileShaderARB(shaderObject);
		
		glGetObjectParameterivARB(shaderObject, 
								  GL_OBJECT_INFO_LOG_LENGTH_ARB, 
								  &infoLogLength);
		
		if( infoLogLength > 0 ) 
		{
			GLcharARB *infoLog = (GLcharARB *)malloc(infoLogLength);
			
			if( infoLog != NULL )
			{
				glGetInfoLogARB(shaderObject, 
								infoLogLength, 
								&infoLogLength, 
								infoLog);
				
				NSLog(@">> Shader compile log:\n%s\n", infoLog);
				
				free(infoLog);
			} // if
		} // if
		
		glGetObjectParameterivARB(shaderObject, 
								  GL_OBJECT_COMPILE_STATUS_ARB, 
								  theShaderCompiled);
		
		if( *theShaderCompiled == 0 )
		{
			NSLog(@">> Failed to compile shader %s\n", theShader);
		} // if
	} // if
	else 
	{
		*theShaderCompiled = 1;
	} // else
	
	return shaderObject;
} // LoadShader

//---------------------------------------------------------------------------------

static void LinkProgram(GLhandleARB programObject, 
						GLint *theProgramLinked) 
{
	GLint  infoLogLength = 0;
	
	glLinkProgramARB(programObject);
	
	glGetObjectParameterivARB(programObject, 
							  GL_OBJECT_INFO_LOG_LENGTH_ARB, 
							  &infoLogLength);
	
	if( infoLogLength >  0 ) 
	{
		GLcharARB *infoLog = (GLcharARB *)malloc(infoLogLength);
		
		if( infoLog != NULL)
		{
			glGetInfoLogARB(programObject, 
							infoLogLength, 
							&infoLogLength, 
							infoLog);
			
			NSLog(@">> Program link log:\n%s\n", infoLog);
			
			free(infoLog);
		} // if
	} // if
	
	glGetObjectParameterivARB(programObject, 
							  GL_OBJECT_LINK_STATUS_ARB, 
							  theProgramLinked);
	
	if( *theProgramLinked == 0 )
	{
		NSLog(@">> Failed to link program 0x%lx\n", (GLubyte *)&programObject);
	} // if
} // LinkProgram

//---------------------------------------------------------------------------------

//---------------------------------------------------------------------------------

@implementation Shader

//---------------------------------------------------------------------------------

#pragma mark -- Get shaders from resource --

//---------------------------------------------------------------------------------

- (GLcharARB *) getShaderSourceFromResource:(NSString *)theShaderResourceName 
								  extension:(NSString *)theExtension
{
	NSBundle  *appBundle = [NSBundle mainBundle];
	
	NSString  *shaderTempSource = [appBundle pathForResource:theShaderResourceName 
													  ofType:theExtension
												 inDirectory:@"Shaders"];
	GLcharARB *shaderSource = NULL;
	
	shaderTempSource = [NSString stringWithContentsOfFile:shaderTempSource];
	shaderSource     = (GLcharARB *)[shaderTempSource cStringUsingEncoding:NSASCIIStringEncoding];
	
	return  shaderSource;
} // getShaderSourceFromResource

//---------------------------------------------------------------------------------

- (void) getFragmentShaderSourceFromResource:(NSString *)theFragmentShaderResourceName
{
	fragmentShaderSource = [self getShaderSourceFromResource:theFragmentShaderResourceName 
												   extension:@"frag" ];
} // getFragmentShaderSourceFromResource

//---------------------------------------------------------------------------------

- (void) getVertexShaderSourceFromResource:(NSString *)theVertexShaderResourceName
{
	vertexShaderSource = [self getShaderSourceFromResource:theVertexShaderResourceName 
												 extension:@"vert" ];
} // getVertexShaderSourceFromResource

//---------------------------------------------------------------------------------

- (GLhandleARB) loadShader:(GLenum)theShaderType 
			  shaderSource:(const GLcharARB **)theShaderSource
{
	GLint       shaderCompiled = 0;
	GLhandleARB shaderHandle   = LoadShader(theShaderType, 
											theShaderSource, 
											&shaderCompiled);
	
	if( !shaderCompiled ) 
	{
		if( shaderHandle ) 
		{
			glDeleteObjectARB(shaderHandle);
			shaderHandle = NULL;
		} // if
	} // if
	
	return shaderHandle;
} // loadShader

//---------------------------------------------------------------------------------

- (BOOL) newProgramObject:(GLhandleARB)theVertexShader  
	 fragmentShaderHandle:(GLhandleARB)theFragmentShader
{
	GLint programLinked = 0;
	
	// Create a program object and link both shaders
	
	programObject = glCreateProgramObjectARB();
	
	glAttachObjectARB(programObject, theVertexShader);
	glDeleteObjectARB(theVertexShader);   // Release
	
	glAttachObjectARB(programObject, theFragmentShader);
	glDeleteObjectARB(theFragmentShader); // Release
	
	LinkProgram(programObject, &programLinked);
	
	if( !programLinked ) 
	{
		glDeleteObjectARB(programObject);
		
		programObject = NULL;
		
		return NO;
	} // if
	
	return YES;
} // newProgramObject

//---------------------------------------------------------------------------------

- (BOOL) setProgramObject
{
	BOOL  programObjectSet = NO;
	
	// Load and compile both shaders
	
	GLhandleARB vertexShader = [self loadShader:GL_VERTEX_SHADER_ARB 
								   shaderSource:&vertexShaderSource];
	
	// Ensure vertex shader compiled
	
	if( vertexShader != NULL )
	{
		GLhandleARB fragmentShader = [self loadShader:GL_FRAGMENT_SHADER_ARB 
										 shaderSource:&fragmentShaderSource];
		
		// Ensure fragment shader compiled
		
		if( fragmentShader != NULL ) 
		{
			// Create a program object and link both shaders
			
			programObjectSet = [self newProgramObject:vertexShader 
								 fragmentShaderHandle:fragmentShader];
		} // if
	} // if
	
	return  programObjectSet;
} // setProgramObject

//---------------------------------------------------------------------------------

#pragma mark -- Designated Initializer --

//---------------------------------------------------------------------------------

- (id) initWithShadersInAppBundle:(NSString *)theShadersName
{
	self = [super init];
	
	if( self)
	{
		BOOL  loadedShaders = NO;
		
		// Load vertex and fragment shader
		
		[self getVertexShaderSourceFromResource:theShadersName];
		
		if( vertexShaderSource != NULL )
		{
			[self getFragmentShaderSourceFromResource:theShadersName];
			
			if( fragmentShaderSource != NULL )
			{
				loadedShaders = [self setProgramObject];
				
				if( !loadedShaders)
				{
					NSLog(@">> WARNING: Failed to load GLSL \"%@\" fragment & vertex shaders!\n", 
						  theShadersName);
				} // if
			} // if
		} // if
	} // if
	
	return self;
} // initWithShadersInAppBundle

//---------------------------------------------------------------------------------

#pragma mark -- Deallocating Resources --

//---------------------------------------------------------------------------------

- (void) dealloc
{
	// Delete OpenGL resources
	
	if( programObject )
	{
		glDeleteObjectARB(programObject);
		
		programObject = NULL;
	} // if
	
	//Dealloc the superclass
	
	[super dealloc];
} // dealloc

//---------------------------------------------------------------------------------

#pragma mark -- Accessors --

//---------------------------------------------------------------------------------

- (GLhandleARB) programObject
{
	return  programObject;
} // programObject

//---------------------------------------------------------------------------------

#pragma mark -- Utilities --

//---------------------------------------------------------------------------------

- (GLint) getUniformLocation:(const GLcharARB *)theUniformName
{
	GLint uniformLoacation = glGetUniformLocationARB(programObject, 
													 theUniformName);
	
	if( uniformLoacation == -1 ) 
	{
		NSLog( @">> WARNING: No such uniform named \"%s\"\n", theUniformName );
	} // if
	
	return uniformLoacation;
} // getUniformLocation

//---------------------------------------------------------------------------------

@end

//---------------------------------------------------------------------------------

//---------------------------------------------------------------------------------

