//
//  ASMarkerDetector.h
//  airstorm-mothership
//
//  Created by LCR on 6/22/13.
//  Copyright (c) 2013 com.nmlab-g7. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ASDetectorDelegate <NSObject>

@required
- (void)setCornerLeftTop:(CGPoint)point;
- (void)setCornerRightTop:(CGPoint)point;
- (void)setCornerRightBottom:(CGPoint)point;
- (void)setCornerLeftBottom:(CGPoint)point;

- (void)detectMarkerId:(int)markerId atAbsPosition:(CGPoint)absPosition;
- (void)markerIsPressed:(NSNumber *)markerId;
// QQ
- (NSRect)getFrameOfMarker:(NSNumber *)markerId;

@end

@interface ASMarkerDetector : NSObject

@property (weak, nonatomic) id<ASDetectorDelegate> delegate;

+ (ASMarkerDetector *)sharedDetector;

- (void)detect;

+ (int)cameraResolutionWidth;
+ (int)cameraResolutionHeight;

@end
