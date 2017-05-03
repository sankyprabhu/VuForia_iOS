/*===============================================================================
 Copyright (c) 2015-2016 PTC Inc. All Rights Reserved. Confidential and Proprietary -
 Protected under copyright and other laws.
 Vuforia is a trademark of PTC Inc., registered in the United States and other
 countries.
 ===============================================================================*/

#import <UIKit/UIKit.h>
#import <Vuforia/UIGLViewProtocol.h>
#import <Metal/Metal.h>

#import "SampleApplicationSession.h"

// ImageTargetsMetalView is a subclass of UIView and conforms to the informal protocol
// UIGLViewProtocol
@interface ImageTargetsMetalView : UIView <UIGLViewProtocol> {
@private
    id<MTLDevice> metalDevice;
    id<MTLRenderPipelineState> pipelineStateVideo;
    id<MTLRenderPipelineState> pipelineStateTeapot;
    id<MTLCommandQueue> metalCommandQueue;
    id<MTLTexture> textureVideo;
    id<MTLTexture> textureTeapot;
    id<MTLBuffer> vertexBufferVideo;
    id<MTLBuffer> vertexBufferTeapot;
    id<MTLBuffer> indexBufferTeapot;
    id<MTLBuffer> texCoordBufferVideo;
    id<MTLBuffer> texCoordBufferTeapot;
    id<MTLBuffer> transformBuffer;
    id<MTLBuffer> orthoProjBuffer;
    id<MTLDepthStencilState> depthStencilState;
    dispatch_semaphore_t commandExecuting;
}

@property (nonatomic, weak) SampleApplicationSession * vapp;

- (id)initWithFrame:(CGRect)frame appSession:(SampleApplicationSession *) app;
- (void) updateRenderingPrimitives;

@end