//
//  ASMarkerDetector.h
//  airstorm-mothership
//
//  Created by LCR on 6/22/13.
//  Copyright (c) 2013 com.nmlab-g7. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ASMarkerDetector : NSObject

+ (void)detect;

+ (int)cameraResolutionWidth;
+ (int)cameraResolutionHeight;

@end
