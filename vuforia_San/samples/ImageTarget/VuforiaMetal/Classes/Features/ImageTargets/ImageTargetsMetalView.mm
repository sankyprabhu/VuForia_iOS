/*===============================================================================
 Copyright (c) 2015-2016 PTC Inc. All Rights Reserved. Confidential and Proprietary -
 Protected under copyright and other laws.
 Vuforia is a trademark of PTC Inc., registered in the United States and other
 countries.
 ===============================================================================*/

#import "ImageTargetsMetalView.h"
#import <QuartzCore/CAMetalLayer.h>
#import <Vuforia/Vuforia.h>
#import <Vuforia/Vuforia_iOS.h>
#import <Vuforia/Device.h>
#import <Vuforia/State.h>
#import <Vuforia/Renderer.h>
#import <Vuforia/MetalRenderer.h>
#import <Vuforia/State.h>
#import <Vuforia/Tool.h>
#import <Vuforia/TrackableResult.h>
#import <Vuforia/CameraDevice.h>
#import <Vuforia/VideoBackgroundTextureInfo.h>

#import "Teapot.h"
#import "Texture.h"
#import "SampleApplicationUtils.h"

namespace {
    // Model scale factor
    const float kObjectScaleNormal = 0.003f;
    
    const uint32_t kMVPMatrixBufferSize = sizeof(Vuforia::Matrix44F);
    
    const uint32_t texCoordCount = 6 * 2;
    const uint32_t texCoordsSize = texCoordCount * sizeof(float);
    
    const uint32_t quadVerticesCount = 6 * 3;
    const uint32_t quadVerticesSize  = quadVerticesCount * sizeof(float);
    
    const float kQuadVertices[quadVerticesCount] =
    {
        1.0f, -1.0f, 0.0f,
        -1.0f, -1.0f, 0.0f,
        1.0f,  1.0f, 0.0f,
        
        1.0f,  1.0f, 0.0f,
        -1.0f, -1.0f, 0.0f,
        -1.0f,  1.0f, 0.0f,
    };
    
    float quadTexCoords[texCoordCount] =
    {
        1.0f, 1.0f,
        0.0f, 1.0f,
        1.0f, 0.0f,
        
        1.0f, 0.0f,
        0.0f, 1.0f,
        0.0f, 0.0f,
    };

}

@interface ImageTargetsMetalView ()
@property (nonatomic) CGFloat contentScaleFactor;
// The current set of rendering primitives
@property (nonatomic, readwrite) Vuforia::RenderingPrimitives *currentRenderingPrimitives;
@end

@implementation ImageTargetsMetalView
@synthesize vapp = vapp;

// You must implement this method, which ensures the view's underlying layer is
// of type CAMetalLayer
+ (Class)layerClass
{
    return [CAMetalLayer class];
}

- (id)initWithFrame:(CGRect)frame appSession:(SampleApplicationSession *) app
{
    self = [super initWithFrame:frame];
    
    if (self) {
        vapp = app;
        [self determineContentScaleFactor];
        [self setContentScaleFactor:self.contentScaleFactor];
        
        // --- Metal device ---
        // Get the system default metal device
        metalDevice = MTLCreateSystemDefaultDevice();
        
        // Metal command queue
        metalCommandQueue = [metalDevice newCommandQueue];
        
        // Create a dispatch semaphore, used to synchronise command execution
        commandExecuting = dispatch_semaphore_create(1);
        
        // --- Metal layer ---
        // Create a CAMetalLayer and set its frame to match that of the view
        CAMetalLayer* layer = (CAMetalLayer*)[self layer];
        layer.device = metalDevice;
        layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
        layer.framebufferOnly = true;
        layer.contentsScale = self.contentScaleFactor;
        
        // --- Metal vertex, index and transform buffers ---
        // Teapot vertex buffer
        vertexBufferTeapot = [metalDevice newBufferWithBytes:teapotVertices length:sizeof(teapotVertices) options:MTLResourceOptionCPUCacheModeDefault];
        
        // Teapot index buffer
        indexBufferTeapot = [metalDevice newBufferWithBytes:teapotIndices length:sizeof(teapotIndices) options:MTLResourceOptionCPUCacheModeDefault];
        
        // Video background vertex buffer
        vertexBufferVideo = [metalDevice newBufferWithBytes:kQuadVertices length:quadVerticesSize options:MTLResourceOptionCPUCacheModeDefault];
        
        // Video background texture coordinate buffer
        NSUInteger teapotTexCoordsSize = sizeof(teapotTexCoords);
        texCoordBufferTeapot = [metalDevice newBufferWithBytes:teapotTexCoords
                                                        length:teapotTexCoordsSize
                                                       options:MTLResourceOptionCPUCacheModeDefault];
        
        // Model view projection matrix buffer
        transformBuffer = [metalDevice newBufferWithLength:kMVPMatrixBufferSize options:0];
        
        // Orthographic projection matrix buffer
        orthoProjBuffer = [metalDevice newBufferWithLength:kMVPMatrixBufferSize options:0];
        
        
        // --- Metal pipeline ---
        // Get the default library from the bundle (Metal shaders)
        id<MTLLibrary> library = [metalDevice newDefaultLibrary];
        
        id<MTLFunction> videoBackgroundVertexFunc = [library newFunctionWithName:@"texturedVertex"];
        id<MTLFunction> videoBackgroundFragmentFunc = [library newFunctionWithName:@"texturedFragment"];
        
        id<MTLFunction> augmentationVertexFunc = [library newFunctionWithName:@"texturedVertex"];
        id<MTLFunction> augmentationFragmentFunc = [library newFunctionWithName:@"texturedFragment"];
        
        // Set up pipeline state descriptor.  Note that the video background and
        // augmention pipeline states are the same, so could be represented by
        // one MTLRenderPipelineDescriptor.  We use two for demonstration only
        MTLRenderPipelineDescriptor* stateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        NSError* error = nil;
        
        // === Video background ===
        stateDescriptor.vertexFunction = videoBackgroundVertexFunc;
        stateDescriptor.fragmentFunction = videoBackgroundFragmentFunc;
        stateDescriptor.colorAttachments[0].pixelFormat = layer.pixelFormat;
        
        // And create the pipeline state with the descriptor
        pipelineStateVideo = [metalDevice newRenderPipelineStateWithDescriptor:stateDescriptor error:&error];
        
        if (nil == pipelineStateVideo) {
            NSLog(@"Failed to create video background render pipeline state: %@", [error localizedDescription]);
        }
        
        // === Augmentation ===
        stateDescriptor.vertexFunction = augmentationVertexFunc;
        stateDescriptor.fragmentFunction = augmentationFragmentFunc;
        stateDescriptor.colorAttachments[0].pixelFormat = layer.pixelFormat;
        
        error = nil;
        pipelineStateTeapot = [metalDevice newRenderPipelineStateWithDescriptor:stateDescriptor error:&error];
        
        if (nil == pipelineStateTeapot) {
            NSLog(@"Failed to create augmentation render pipeline state: %@", [error localizedDescription]);
        }
        
        // Fragment depth stencil
        MTLDepthStencilDescriptor* depthStencilDescriptor = [[MTLDepthStencilDescriptor alloc] init];
        depthStencilDescriptor.depthCompareFunction = MTLCompareFunctionLess;
        depthStencilDescriptor.depthWriteEnabled = YES;
        depthStencilState = [metalDevice newDepthStencilStateWithDescriptor:depthStencilDescriptor];
        
        // Load the teapot texture data
        Texture* texture = [[Texture alloc] initWithImageFile:@"TextureTeapotBrass.png"];
        
        MTLTextureDescriptor* textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                                     width:[texture width]
                                                                                                    height:[texture height]
                                                                                                 mipmapped:YES];
        textureTeapot = [metalDevice newTextureWithDescriptor:textureDescriptor];
        
        Vuforia::Device& device = Vuforia::Device::getInstance();
        if (!device.setMode(Vuforia::Device::MODE_AR)) {
            NSLog(@"ERROR: failed to set the device mode");
        };
        device.setViewerActive(false);
        
        MTLRegion region = MTLRegionMake2D(0, 0, [texture width], [texture height]);
        [textureTeapot replaceRegion:region mipmapLevel:0 withBytes:[texture pngData] bytesPerRow:[texture width] * [texture channels]];
    }
    
    return self;
}

- (void)determineContentScaleFactor
{
    UIScreen* mainScreen = [UIScreen mainScreen];
    
    self.contentScaleFactor = [mainScreen nativeScale];
}

- (void)updateRenderingPrimitives
{
    delete self.currentRenderingPrimitives;
    self.currentRenderingPrimitives = new Vuforia::RenderingPrimitives(Vuforia::Device::getInstance().getRenderingPrimitives());
}

//------------------------------------------------------------------------------
#pragma mark - UIGLViewProtocol protocol

// Draw the current frame using Metal
//
// This method is called by Vuforia when it wishes to render the current frame to
// the screen.
//
// *** Vuforia will call this method periodically on a background thread ***
- (void)renderFrameVuforia
{
    if (! vapp.cameraIsStarted) {
        return;
    }
    
    // Now the camera has been started, perform one time operations:
    // * copy the ortho projection data into the Metal buffer
    // * if we (the app) own the video background texture:
    //   create the video background MTLTexture of the appropriate size and
    //   pass the texture ID to Vuforia so it can store the video background
    //   frame data for us to render
    
    if (! texCoordBufferVideo) {
        // Copy orthographic projection matrix into Metal buffer
        uint8_t* buffer = (uint8_t*)[orthoProjBuffer contents];
        memcpy(buffer, &vapp.orthoProjMatrix.data[0], sizeof(vapp.orthoProjMatrix.data));
    }
    
    // ========== Set up ==========
    CAMetalLayer* layer = (CAMetalLayer*)self.layer;
    
    MTLViewport viewport;
    viewport.originX = 0.0f;
    viewport.originY = 0.0f;
    viewport.height = layer.drawableSize.height;
    viewport.width = layer.drawableSize.width;
    viewport.znear = 0.0f;
    viewport.zfar = 1.0f;
    
    // --- Command buffer ---
    // Get the command buffer from the command queue
    id<MTLCommandBuffer>commandBuffer = [metalCommandQueue commandBuffer];
    
    // Get the next drawable from the CAMetalLayer
    id<CAMetalDrawable> drawable = [layer nextDrawable];

    // It's possible for nextDrawable to return nil, which means a call to
    // renderCommandEncoderWithDescriptor will fail
    if (!drawable) {
        return;
    }

    // Wait for exclusive access to the GPU
    dispatch_semaphore_wait(commandExecuting, DISPATCH_TIME_FOREVER);
    
    // -- Render pass descriptor ---
    // Set up a render pass decriptor
    MTLRenderPassDescriptor* renderPassDescriptor = [[MTLRenderPassDescriptor  alloc] init];

    // Draw to the drawable's texture
    renderPassDescriptor.colorAttachments[0].texture = [drawable texture];
    // Clear the colour attachment in case there is no video frame
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    // Store the data in the texture when rendering is complete
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

    // Get a command encoder to encode into the command buffer
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    
    // Begin Vuforia rendering for this frame, retrieving the tracking state
    static Vuforia::MetalRenderData renderData;
    renderData.mData.drawableTexture = [drawable texture];
    renderData.mData.commandEncoder = encoder;
    Vuforia::State state = Vuforia::Renderer::getInstance().begin(&renderData);

    if(self.currentRenderingPrimitives == nullptr)
        [self updateRenderingPrimitives];
    
    Vuforia::ViewList& viewList = self.currentRenderingPrimitives->getRenderingViews();
    
    // Iterate over the ViewList
    for (int viewIdx = 0; viewIdx < viewList.getNumViews(); viewIdx++) {
        Vuforia::VIEW vw = viewList.getView(viewIdx);
        
        // Set up the viewport
        Vuforia::Vec4I viewportInfo;
        // We're writing directly to the screen, so the viewport is relative to the screen
        viewportInfo = self.currentRenderingPrimitives->getViewport(vw);
        
        Vuforia::Matrix34F projMatrix = self.currentRenderingPrimitives->getProjectionMatrix(vw,
                                                                                Vuforia::COORDINATE_SYSTEM_CAMERA);
        float nearPlane = 0.01f;
        float farPlane = 5.f;
        Vuforia::Matrix44F rawProjectionMatrixGL = Vuforia::Tool::convertPerspectiveProjection2GLMatrix(
                                                                                                        projMatrix,
                                                                                                        nearPlane,
                                                                                                        farPlane);
        
        viewport.originX = viewportInfo.data[0];
        viewport.originY = viewportInfo.data[1];
        viewport.width = viewportInfo.data[2];
        viewport.height = viewportInfo.data[3];
        viewport.znear = 0.0f;
        viewport.zfar = 1.0f;

        // Apply the appropriate eye adjustment to the raw projection matrix, and assign to the global variable
        Vuforia::Matrix44F eyeAdjustmentGL = Vuforia::Tool::convert2GLMatrix(self.currentRenderingPrimitives->getEyeDisplayAdjustmentMatrix(vw));
        
        Vuforia::Matrix44F projectionMatrix;
        SampleApplicationUtils::multiplyMatrix(&rawProjectionMatrixGL.data[0], &eyeAdjustmentGL.data[0], &projectionMatrix.data[0]);

        //render = Vuforia::Renderer::getInstance().drawVideoBackground();

        // Vuforia will set the fragment texture on the encoder, at the index we
        // specify (MTLRenderCommandEncoder setFragmentTexture:atIndex:)
        static Vuforia::MetalTextureUnit unit;
        unit.mTextureIndex = 0;
        if (Vuforia::Renderer::getInstance().updateVideoBackgroundTexture(&unit)) {
            // Now a bind operation has taken place, perform one time operations:
            // If we (the app) do not own the video background texture:
            // * calculate the texture coordinate ratio to use when sampling from
            //   the video background texture.  We can obtain the information we
            //   need from Vuforia (VideoBackgroundTextureInfo)
            
            if (! texCoordBufferVideo) {
                // Set our texture coordinate ratios
                Vuforia::VideoBackgroundTextureInfo info = Vuforia::Renderer::getInstance().getVideoBackgroundTextureInfo();
                float uRatio = (float)info.mImageSize.data[0] / info.mTextureSize.data[0];
                float vRatio = (float)info.mImageSize.data[1] / info.mTextureSize.data[1];
                
                for (float* p = quadTexCoords; p < quadTexCoords + texCoordCount;) {
                    *p = ((*p) != 0 ) ? uRatio : 0.0;
                    p++;
                    *p = ((*p) != 0 ) ? vRatio : 0.0;
                    p++;
                }
                
                texCoordBufferVideo = [metalDevice newBufferWithBytes:quadTexCoords
                                                               length:texCoordsSize
                                                              options:MTLResourceOptionCPUCacheModeDefault];
            };
            
            
            // ========== Render the video background ==========
            // Set the render pipeline state
            [encoder setRenderPipelineState:pipelineStateVideo];
            
            // Set the texture coordinate buffer
            [encoder setVertexBuffer:texCoordBufferVideo
                              offset:0
                             atIndex:2];
            
            // Set the vertex buffer
            [encoder setVertexBuffer:vertexBufferVideo offset:0 atIndex:0];
            
            // Set the projection matrix
            [encoder setVertexBuffer:orthoProjBuffer offset:0 atIndex:1];

        
            [encoder setViewport:viewport];
        
            // Draw the geometry
            [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
            
            // Set the pipeline state
            [encoder setRenderPipelineState:pipelineStateTeapot];
        
            // Enable depth testing
            [encoder setDepthStencilState:depthStencilState];
        
            for (int i = 0; i < state.getNumTrackableResults(); ++i) {
                // Get the trackable result
                const Vuforia::TrackableResult* result = state.getTrackableResult(i);
            
                Vuforia::Matrix44F modelViewMatrix = Vuforia::Tool::convertPose2GLMatrix(result->getPose());
                Vuforia::Matrix44F modelViewProjection;
            
                SampleApplicationUtils::translatePoseMatrix(0.0f, 0.0f, kObjectScaleNormal, &modelViewMatrix.data[0]);
                SampleApplicationUtils::scalePoseMatrix(kObjectScaleNormal, kObjectScaleNormal, kObjectScaleNormal, &modelViewMatrix.data[0]);
            
                SampleApplicationUtils::multiplyMatrix(&projectionMatrix.data[0], &modelViewMatrix.data[0], &modelViewProjection.data[0]);
            
            
                // ========== Render the augmentation ==========
                // Set the vertex buffer
                [encoder setVertexBuffer:vertexBufferTeapot offset:0 atIndex:0];
            
                // Set the fragment texture
                [encoder setFragmentTexture:textureTeapot atIndex:0];
            
                // Set the texture coordinate buffer
                [encoder setVertexBuffer:texCoordBufferTeapot
                              offset:0
                             atIndex:2];
            
                // Load MVP constant buffer data into appropriate buffer
                uint8_t* buffer = (uint8_t*)[transformBuffer contents];
                memcpy(buffer, &modelViewProjection, sizeof(modelViewProjection));
                [encoder setVertexBuffer:transformBuffer offset:0 atIndex:1];
            
                // Set the viewport
                [encoder setViewport:viewport];
            
                // Draw the geometry
                [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:NUM_TEAPOT_OBJECT_INDEX indexType:MTLIndexTypeUInt16 indexBuffer:indexBufferTeapot indexBufferOffset:0];
            }
        }
    }
    
    // Pass Metal context data to Vuforia (we may have changed the encoder since
    // calling Vuforia::Renderer::begin)
    Vuforia::Renderer::getInstance().end(&renderData);
    
    // Remove reference, because otherwise the encoder-object leaks.
    renderData.mData.commandEncoder = nullptr;
    
    // ========== Finish Metal rendering ==========
    [encoder endEncoding];
    
    // Commit the rendering commands
    // Command completed handler
    [commandBuffer addCompletedHandler:^(id <MTLCommandBuffer> cmdb) {
        dispatch_semaphore_signal(commandExecuting);
    }];
    
    
    // Present the drawable when the command buffer has been executed (Metal
    // calls to CoreAnimation to tell it to put the texture on the display when
    // the rendering is complete)
    [commandBuffer presentDrawable:drawable];
    
    // Commit the command buffer for execution as soon as possible
    [commandBuffer commit];
}


@end
