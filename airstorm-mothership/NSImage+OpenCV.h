//
//  NSImage+OpenCV.h
//
//  Created by TangQiao on 12-10-26.
//

#import <Foundation/Foundation.h>
#import "opencv2/opencv.hpp"

@interface NSImage (OpenCV)

+(NSImage*)imageWithCVMat:(const cv::Mat&)cvMat;
-(id)initWithCVMat:(const cv::Mat&)cvMat;

@property(nonatomic, readonly) cv::Mat CVMat;
@property(nonatomic, readonly) cv::Mat CVGrayscaleMat;

@end