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
- (void)setCornerLeftTopWithMarkerCenter:(CGPoint)center andOffset:(CGPoint)offset;
- (void)setCornerRightTopWithMarkerCenter:(CGPoint)center andOffset:(CGPoint)offset;
- (void)setCornerRightBottomWithMarkerCenter:(CGPoint)center andOffset:(CGPoint)offset;
- (void)setCornerLeftBottomWithMarkerCenter:(CGPoint)center andOffset:(CGPoint)offset;

- (void)detectMarkerId:(int)markerId atAbsPosition:(CGPoint)absPosition;
- (void)markerIsPressed:(NSNumber *)markerId;

- (BOOL)markerIsVideo:(NSNumber *)markerId;
- (void)prepareToHideAnchor;
- (void)stopHideAnchor;
// QQ
- (NSRect)getFrameOfMarker:(NSNumber *)markerId;
- (float)scaleRatioOfProjection;
@end

@interface ASMarkerDetector : NSObject

@property (weak, nonatomic) id<ASDetectorDelegate> delegate;
@property BOOL isAnchor0Set, isAnchor1Set, isAnchor2Set, isAnchor3Set;

+ (ASMarkerDetector *)sharedDetector;

- (void)detect;

+ (int)cameraResolutionWidth;
+ (int)cameraResolutionHeight;

@end
