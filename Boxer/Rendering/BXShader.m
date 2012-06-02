/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXShader.h"


NSString * const BXShaderErrorDomain = @"BXShaderErrorDomain";
NSString * const BXShaderErrorSourceKey = @"Source";
NSString * const BXShaderErrorInfoLogKey = @"Info log";


@interface BXShader ()
@property (readwrite, nonatomic) GLhandleARB shaderProgram;
@end

@implementation BXShader
@synthesize shaderProgram = _shaderProgram;


#pragma mark -
#pragma mark Compilation helper methods

+ (NSString *) infoLogForObject: (GLhandleARB)objectHandle
{
    NSString *infoLog = nil;
    GLint infoLogLength = 0;
    
    glGetObjectParameterivARB(objectHandle, GL_OBJECT_INFO_LOG_LENGTH_ARB, &infoLogLength);
    if (infoLogLength > 0) 
    {
        GLcharARB *infoLogChars = (GLcharARB *)malloc(infoLogLength);
        
        if (infoLogChars != NULL)
        {
            glGetInfoLogARB(objectHandle, infoLogLength, &infoLogLength, infoLogChars);
            
            infoLog = [NSString stringWithCString: (const char *)infoLogChars
                                         encoding: NSASCIIStringEncoding];
            
            free(infoLogChars);
        }
    }
    return infoLog;
}

+ (GLhandleARB) createShaderWithSource: (NSString *)source
                                  type: (GLenum)shaderType
                                 error: (NSError **)outError
{
    GLhandleARB shaderHandle = NULL;
    BOOL compiled = NO;
    
    if (source.length)
    {
        const GLcharARB *glSource = (const GLcharARB *)[source cStringUsingEncoding: NSASCIIStringEncoding];
    
        shaderHandle = glCreateShaderObjectARB(shaderType);
        
        glShaderSourceARB(shaderHandle, 1, &glSource, NULL);
        glCompileShaderARB(shaderHandle);
        
        //After compilation, check if compilation succeeded.
        GLint status = GL_FALSE;
        glGetObjectParameterivARB(shaderHandle, 
                                  GL_OBJECT_COMPILE_STATUS_ARB, 
                                  &status);
            
        compiled = (status != GL_FALSE);
    }

    if (!compiled)
    {   
        //Pass an error back up about what we couldn't compile.
        if (outError)
        {
            BOOL isVertexShader = (shaderType == GL_VERTEX_SHADER_ARB || shaderType == GL_VERTEX_SHADER);
            NSInteger compileError = (isVertexShader) ? BXShaderCouldNotCompileVertexShader : BXShaderCouldNotCompileFragmentShader;
            
            //Read out the info log to give some clue as to why compilation failed.
            NSString *infoLog = (shaderHandle) ? [self infoLogForObject: shaderHandle] : @"";
                
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      source, BXShaderErrorSourceKey,
                                      infoLog, BXShaderErrorInfoLogKey,
                                      nil];
            
            
            *outError = [NSError errorWithDomain: BXShaderErrorDomain
                                            code: compileError
                                        userInfo: userInfo];
        }
        
        //Clean up any leftover handle if we couldn't compile.
        if (shaderHandle)
        {
            glDeleteObjectARB(shaderHandle);
            shaderHandle = NULL;
        }
    }
    
    return shaderHandle;
}

+ (GLhandleARB) createProgramWithVertexShader: (NSString *)vertexSource
                              fragmentShaders: (NSArray *)fragmentSources
                                        error: (NSError **)outError
{
    GLhandleARB programHandle = glCreateProgramObjectARB();
    
    NSAssert(vertexSource != nil || fragmentSources.count > 0, @"No vertex shader or fragment shader supplied for program.");
    
    if (vertexSource)
    {
        GLhandleARB vertexShader = [self createShaderWithSource: vertexSource
                                                           type: GL_VERTEX_SHADER_ARB
                                                          error: outError];

        if (vertexShader)
        {
            glAttachObjectARB(programHandle, vertexShader);
            glDeleteObjectARB(vertexShader);
        }
        else
        {
            //Bail if we couldn't compile a shader (in which case outError will have been populated).
            glDeleteObjectARB(programHandle);
            return NULL;
        }
    }
    
    for (NSString *fragmentSource in fragmentSources)
    {
        GLhandleARB fragmentShader = [self createShaderWithSource: fragmentSource
                                                             type: GL_FRAGMENT_SHADER_ARB
                                                            error: outError];
        
        if (fragmentShader)
        {
            glAttachObjectARB(programHandle, fragmentShader);
            glDeleteObjectARB(fragmentShader);
        }
        else
        {
            //Bail if we couldn't compile a shader (in which case outError will have been populated).
            glDeleteObjectARB(programHandle);
            return NULL;
        }
    }
    
    //Once we've attached all the shaders, try linking and validating the final program.
	glLinkProgramARB(programHandle);
	glValidateProgramARB(programHandle);
    
    GLint linked = GL_FALSE;
    GLint validated = GL_FALSE;
	glGetObjectParameterivARB(programHandle, GL_OBJECT_LINK_STATUS_ARB, &linked);
	glGetObjectParameterivARB(programHandle, GL_OBJECT_VALIDATE_STATUS_ARB, &validated);
	
    //If the program didn't link, throw an error upstream and clean up after ourselves.
	if (linked == GL_FALSE || validated == GL_FALSE)
	{
        if (outError)
        {
            //Read out the info log to give some clue as to why linking failed.
            NSString *infoLog = (programHandle) ? [self infoLogForObject: programHandle] : @"";
            
            NSDictionary *userInfo = [NSDictionary dictionaryWithObject: infoLog
                                                                 forKey: BXShaderErrorInfoLogKey];
            
            *outError = [NSError errorWithDomain: BXShaderErrorDomain
                                            code: BXShaderCouldNotCreateShaderProgram
                                        userInfo: userInfo];
        }
        
        if (programHandle)
        {
            glDeleteObjectARB(programHandle);
        }
        
        return NULL;
	}
    
    //If we got this far, everything's A-OK!
    return programHandle;
}


#pragma mark -
#pragma mark Initialization and deallocation

+ (id) shaderNamed: (NSString *)shaderName error: (NSError **)outError
{
    NSURL *vertexURL    = [[NSBundle mainBundle] URLForResource: shaderName withExtension: @"vert"];
    NSURL *fragmentURL  = [[NSBundle mainBundle] URLForResource: shaderName withExtension: @"frag"];
    
    return [[[self alloc] initWithContentsOfVertexShaderURL: vertexURL
                                         fragmentShaderURLs: [NSArray arrayWithObject: fragmentURL]
                                                      error: outError] autorelease];
}

+ (id) shaderNamed: (NSString *)shaderName inSubdirectory: (NSString *)subdirectory error: (NSError **)outError
{
    NSURL *vertexURL    = [[NSBundle mainBundle] URLForResource: shaderName withExtension: @"vert" subdirectory: subdirectory];
    NSURL *fragmentURL  = [[NSBundle mainBundle] URLForResource: shaderName withExtension: @"frag" subdirectory: subdirectory];
    
    return [[[self alloc] initWithContentsOfVertexShaderURL: vertexURL
                                         fragmentShaderURLs: [NSArray arrayWithObject: fragmentURL]
                                                      error: outError] autorelease];
}

- (id) initWithContentsOfVertexShaderURL: (NSURL *)vertexShaderURL
                      fragmentShaderURLs: (NSArray *)fragmentShaderURLs
                                   error: (NSError **)outError
{
    NSString *vertexSource = nil;
    if (vertexShaderURL)
    {
        vertexSource = [NSString stringWithContentsOfURL: vertexShaderURL
                                                encoding: NSASCIIStringEncoding
                                                   error: outError];
        if (!vertexSource)
        {
            [self release];
            return nil;
        }
    }
    
    NSMutableArray *fragmentSources = [NSMutableArray arrayWithCapacity: fragmentShaderURLs.count];
    for (NSURL *fragmentShaderURL in fragmentShaderURLs)
    {
        NSString *fragmentSource = [NSString stringWithContentsOfURL: fragmentShaderURL
                                                            encoding: NSASCIIStringEncoding
                                                               error: outError];
        
        if (fragmentSource)
        {
            [fragmentSources addObject: fragmentSource];
        }
        else
        {
            [self release];
            return nil;
        }
    }
    
    return [self initWithVertexShader: vertexSource
                      fragmentShaders: fragmentSources
                                error: outError];
}

- (id) initWithVertexShader: (NSString *)vertexSource
            fragmentShaders: (NSArray *)fragmentSources
                      error: (NSError **)outError
{
    if (self = [self init])
    {
        self.shaderProgram = [self.class createProgramWithVertexShader: vertexSource
                                                       fragmentShaders: fragmentSources
                                                                 error: outError];
        
        _freeShaderWhenDone = YES;
        
        //If we couldn't compile a shader program from the specified sources,
        //pack up and go home.
        if (!self.shaderProgram)
        {
            [self release];
            self = nil;
        }
    }
    
    return self;
}

- (void) dealloc
{
    self.shaderProgram = NULL;
    
    [super dealloc];
}

- (void) setShaderProgram: (GLhandleARB)shaderProgram
{
    if (_shaderProgram != shaderProgram)
    {
        if (_shaderProgram && _freeShaderWhenDone)
            glDeleteObjectARB(_shaderProgram);
            
        _shaderProgram = shaderProgram;
    }
}

- (void) setShaderProgram: (GLhandleARB)shaderProgram
             freeWhenDone: (BOOL)freeWhenDone
{
    self.shaderProgram = shaderProgram;
    _freeShaderWhenDone = freeWhenDone;
}

- (GLint) locationOfUniform: (const GLcharARB *)uniformName
{
    return glGetUniformLocationARB(self.shaderProgram, uniformName);
}

@end
