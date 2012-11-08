//
// EffectView
//

#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#include <OpenGLES/ES2/gl.h>

#import "EffectView.h"

#define USE_DEPTH_BUFFER 0

namespace
{
    bool ReadFile(uint8_t* buffer, int bufferSize, NSString* filename)
    {
        memset(buffer, 0, bufferSize);
        
        NSString* pathStr = [[NSString alloc] initWithFormat:@"%@/%@", [[NSBundle mainBundle] resourcePath], filename];
        const char* path = [pathStr cStringUsingEncoding:NSASCIIStringEncoding];
        FILE* fin = fopen(path, "ra");
        if (fin == NULL)
            return false;
        [pathStr release];
        
        fread(buffer, 1, bufferSize, fin);
        
        fclose(fin);
        return true;
    }
    
    int LoadShader (GLenum type, const uint8_t* source)
    {
        const unsigned int shader = glCreateShader(type);
        if (shader == 0)
            return 0;
        
        glShaderSource(shader, 1, (const GLchar**)&source, NULL);
        glCompileShader(shader);
        
        int success;
        glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
        if (success == 0)
        {
            char errorMsg[2048];
            glGetShaderInfoLog(shader, sizeof(errorMsg), NULL, errorMsg);
            printf("Shader compile error: %s\n", errorMsg);
            glDeleteShader(shader);
            return 0;
        }
        
        return shader;
    }
}


// Private methods
@interface EffectView ()

@property (nonatomic, retain) EAGLContext *context;
@property (nonatomic, assign) NSTimer *animationTimer;
@property (nonatomic, assign) NSTimeInterval animationInterval;
@property (nonatomic, assign) float m_waveControl;     //0 to 1

- (BOOL) createFramebuffer;
- (void) destroyFramebuffer;
- (void) drawView;

@end


@implementation EffectView
{
    /* The pixel dimensions of the backbuffer */
    GLint backingWidth;
    GLint backingHeight;
    
    EAGLContext *context;   
    GLuint viewRenderbuffer, viewFramebuffer;
    GLuint depthRenderbuffer;
    
	int m_shaderProgram; 
	int m_a_positionHandle;
	int m_a_colorHandle;
	int m_u_mvpHandle;	
	
    //properties for ripple effect
    int m_texCoord;
	int m_wave;
	int m_waveWidth;
	int m_waveOriginX;
	int m_waveOriginY;
	int m_aspectRatio;
    int m_sampler2d;
    GLuint texture;

    NSTimer *animationTimer;
    NSTimeInterval animationInterval;
}

@synthesize delegate;
@synthesize context;
@synthesize animationTimer;
@synthesize animationInterval;
@synthesize m_waveControl;
@synthesize duration;


#pragma mark - Initialization

// This is a must for OpenGL layer
+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (id)initWithFrame:(CGRect)frame andImage:(UIImage*)image
{
    self = [super initWithFrame:frame];
    if (!self)
        return nil;
    
    // Get the layer
    CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
    
    // Transparent
    eaglLayer.opaque = YES;
    eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
    
    // Make sure this is the right version!
    context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (!context || ![EAGLContext setCurrentContext:context]) {
        [self release];
        return nil;
    }
    
    const bool ok = [self compileShader];
    assert(ok);
    
    texture = [self setupTextureFromImage:image];
    
    self.duration = 3.0f;
    self.animationInterval = 1.0 / 60.0;
    [self resetEffect:YES];

    return self;
}

- (void)dealloc
{
    [self stopAnimation];
    
    if ([EAGLContext currentContext] == context)
        [EAGLContext setCurrentContext:nil];
    
    [context release];  
    [super dealloc];
}


#pragma mark - Animation control

- (void)startAnimation
{
    if (self.animationTimer != nil)
        return;
    self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:animationInterval target:self selector:@selector(drawView) userInfo:nil repeats:YES];
}

- (void)stopAnimation
{
    [self.animationTimer invalidate];
    self.animationTimer = nil;
}

- (void)resetEffect:(BOOL)redraw
{
    self.m_waveControl = 0;
    if (redraw)
        [self drawView];
}

- (void)setAnimationInterval:(NSTimeInterval)interval
{
    animationInterval = interval;
    if (animationTimer) {
        [self stopAnimation];
        [self startAnimation];
    }
}


#pragma mark - Hardcore stuff

- (bool) compileShader
{
	uint8_t buffer[1024];

	if (!ReadFile(buffer, sizeof(buffer), @"VertexShader.txt"))
		return false;
	const int vertexShader = LoadShader (GL_VERTEX_SHADER, buffer);
	if (vertexShader == 0)
		return false;

	if (!ReadFile(buffer, sizeof(buffer), @"RadialWaveShader.txt"))
		return false;
	const int fragmentShader = LoadShader (GL_FRAGMENT_SHADER, buffer);
	if (fragmentShader == 0)
		return false;

	m_shaderProgram = glCreateProgram();
	if (m_shaderProgram == 0)
      return false;

	glAttachShader(m_shaderProgram, vertexShader);
	glAttachShader(m_shaderProgram, fragmentShader);
	glLinkProgram(m_shaderProgram);
	int linked;
	glGetProgramiv(m_shaderProgram, GL_LINK_STATUS, &linked);
	if (linked == 0) 
	{
        NSLog(@"Shader linking error. Check that varying variables in Fragment shader is indeed passed from Vertex shader.");
		glDeleteProgram(m_shaderProgram);
		return false;
	}

    //vertex shader properties
	m_u_mvpHandle = glGetUniformLocation(m_shaderProgram, "u_mvpMatrix");
    m_a_positionHandle = glGetAttribLocation(m_shaderProgram, "a_position");
	m_a_colorHandle = glGetAttribLocation(m_shaderProgram, "a_color");
    
    //fraqment shader properties
    m_texCoord = glGetAttribLocation(m_shaderProgram, "texCoordIn");
	m_wave = glGetUniformLocation(m_shaderProgram, "wave");
	m_waveWidth = glGetUniformLocation(m_shaderProgram, "waveWidth");
  	m_waveOriginX = glGetUniformLocation(m_shaderProgram, "waveOriginX");
	m_waveOriginY = glGetUniformLocation(m_shaderProgram, "waveOriginY");
	m_aspectRatio = glGetUniformLocation(m_shaderProgram, "aspectRatio");
	m_sampler2d = glGetUniformLocation(m_shaderProgram, "sampler2d");
    
	return true;
}

- (void)drawView 
{
    GLfloat squareVertices[] = {
        -1, -1,
         1, -1,
        -1,  1,
         1,  1,
    };
    const GLfloat squareColors[] = {
        1, 1, 0, 1,
        0, 1, 1, 1,
        0, 0, 0, 1,
        1, 0, 1, 1,
    };
    const GLfloat textureVertices[] = {
        0, 1,
        1, 1,
        0, 0,
        1, 0,
    };
    
    //Projection matrix
    GLfloat projection[16];
    SetOrtho(projection, -1, 1, -1, 1, -1.0f, 1.0f);
    
    //Animate the wave
    self.m_waveControl += 1.0 / (self.duration * (1.0/self.animationInterval));

    //Stop after 1 cycle
    if (self.m_waveControl > 1.0f)
    {
        self.m_waveControl = 0;
        [self stopAnimation];
        if ([self.delegate respondsToSelector:@selector(effectDidStop:)])
            [self.delegate effectDidStop:self];
        return;
    }
    
    [EAGLContext setCurrentContext:context];
    
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
    //glViewport(0, 0, backingWidth, backingHeight);
    glViewport(0, 0, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
    glOrthof(-1, 1, -1, 1, -1.0f, 1.0f);

    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);

	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    	
	glUseProgram(m_shaderProgram);
	
	glVertexAttribPointer(m_a_positionHandle, 2, GL_FLOAT, GL_FALSE, 0, squareVertices);
	glEnableVertexAttribArray(m_a_positionHandle);
	glVertexAttribPointer(m_a_colorHandle, 4, GL_FLOAT, GL_FALSE, 0, squareColors);
	glEnableVertexAttribArray(m_a_colorHandle);
	glUniformMatrix4fv(m_u_mvpHandle, 1, GL_FALSE, (GLfloat*)&projection[0] );
    
    //properties for ripple effect
    glUniform1f(m_wave, self.m_waveControl);
    glUniform1f(m_waveWidth, 0.08f);
    glUniform1f(m_waveOriginX, 0.5f);
    glUniform1f(m_waveOriginY, 0.5f);
    glUniform1f(m_aspectRatio, CGRectGetWidth(self.bounds) / CGRectGetHeight(self.bounds));
    glUniform1f(m_aspectRatio, 1.0);
    
    //texture stuff
    glVertexAttribPointer(m_texCoord, 2, GL_FLOAT, GL_FALSE, 0, textureVertices);
    glEnableVertexAttribArray(m_texCoord);
    
    glActiveTexture(GL_TEXTURE0); 
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE); 
    glUniform1i(m_sampler2d, 0);
   
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
    [context presentRenderbuffer:GL_RENDERBUFFER_OES];
}

- (void)layoutSubviews
{
    [EAGLContext setCurrentContext:context];
    [self destroyFramebuffer];
    [self createFramebuffer];
    [self drawView];
}

- (BOOL)createFramebuffer
{
    
    glGenFramebuffersOES(1, &viewFramebuffer);
    glGenRenderbuffersOES(1, &viewRenderbuffer);
    
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
    [context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(CAEAGLLayer*)self.layer];
    glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, viewRenderbuffer);
    
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
    
    if (USE_DEPTH_BUFFER) {
        glGenRenderbuffersOES(1, &depthRenderbuffer);
        glBindRenderbufferOES(GL_RENDERBUFFER_OES, depthRenderbuffer);
        glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, backingWidth, backingHeight);
        glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, depthRenderbuffer);
    }
    
    if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) {
        NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
        return NO;
    }
    
    return YES;
}

- (void)destroyFramebuffer
{
    glDeleteFramebuffersOES(1, &viewFramebuffer);
    viewFramebuffer = 0;
    glDeleteRenderbuffersOES(1, &viewRenderbuffer);
    viewRenderbuffer = 0;
    
    if(depthRenderbuffer) {
        glDeleteRenderbuffersOES(1, &depthRenderbuffer);
        depthRenderbuffer = 0;
    }
}

- (GLuint)setupTextureFromImage:(UIImage *)image
{    
    CGImageRef spriteImage = image.CGImage;
    if (!spriteImage) {
        NSLog(@"Failed to load texture image");
        exit(1);
    }
    
    // 2
    size_t width = CGImageGetWidth(spriteImage);
    size_t height = CGImageGetHeight(spriteImage);
    
    GLubyte * spriteData = (GLubyte *) calloc(width*height*4, sizeof(GLubyte));
    
    CGContextRef spriteContext = CGBitmapContextCreate(spriteData, width, height, 8, width*4, 
                                                       CGImageGetColorSpace(spriteImage), kCGImageAlphaPremultipliedLast);    
    
    // 3
    CGContextDrawImage(spriteContext, CGRectMake(0, 0, width, height), spriteImage);
    
    CGContextRelease(spriteContext);
    
    // 4
    GLuint texName;
    glGenTextures(1, &texName);
    glBindTexture(GL_TEXTURE_2D, texName);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST); 
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, spriteData);
    
    free(spriteData);        
    return texName;    
}

//
// Reference: http://www.opengl.org/sdk/docs/man/xhtml/glOrtho.xml
//
void SetOrtho(GLfloat m[], float left, float right, float bottom, float top, float near, float far)
{
	float tx = - (right + left)/(right - left);
	float ty = - (top + bottom)/(top - bottom);
	float tz = - (far + near)/(far - near);
    
	m[0] = 2.0f/(right-left);
	m[1] = 0;
	m[2] = 0;
	m[3] = tx;
	
	m[4] = 0;
	m[5] = 2.0f/(top-bottom);
	m[6] = 0;
	m[7] = ty;
	
	m[8] = 0;
	m[9] = 0;
	m[10] = -2.0/(far-near);
	m[11] = tz;
	
	m[12] = 0;
	m[13] = 0;
	m[14] = 0;
	m[15] = 1;
}

@end
