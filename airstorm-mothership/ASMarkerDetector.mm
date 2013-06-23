//
//  ASMarkerDetector.m
//  airstorm-mothership
//
//  Created by LCR on 6/22/13.
//  Copyright (c) 2013 com.nmlab-g7. All rights reserved.
//

#import "ASMarkerDetector.h"
#import "ASAppDelegate.h"
#include <iostream>
#include <opencv2/opencv.hpp>
#include "aruco.h"
#include "arucofidmarkers.h"
#include <vector>


using namespace std;
using namespace cv;
using namespace aruco;


@implementation ASMarkerDetector

+ (void)detect
{
    
    //    namedWindow("image", CV_WINDOW_AUTOSIZE);
    //    imshow("image", img);
    //    waitKey();
    
//    Mat marker = aruco::FiducidalMarkers::createMarkerImage(2,500);
//    cv::imwrite("/Users/LCR/Downloads/image.jpg",marker);
    
    bool isDetected = NO;
    
    try
    {
        
        aruco::CameraParameters CamParam;
        MarkerDetector MDetector;
        vector<aruco::Marker> Markers;
        float MarkerSize=0.1;
        
        try {
            CamParam.readFromXMLFile("/tmp/airtorm-camarea-calibration.yml");
        } catch (cv::Exception) {
            NSAlert *alert = [NSAlert alertWithMessageText:@"Calibration file not found" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Please calibrate first."];
            [alert beginSheetModalForWindow:nil modalDelegate:nil didEndSelector:nil contextInfo:nil];
            return;
        }
//        CamParam.resize(InImage.size());
        
        
        CvCapture* capture = 0;
        Mat frame, frameCopy, image;
        
        capture = cvCaptureFromCAM( 0 ); //0=default, -1=any camera, 1..99=your camera
        if(!capture) cout << "No camera detected" << endl;
        
        cvNamedWindow( "Marker Detector", 1 );
        
        if( capture )
        {
            cout << "In capture ..." << endl;
            for(;;)
            {
                IplImage* iplImg = cvQueryFrame( capture );
                frame = iplImg;
                if( frame.empty() )
                    break;
                if( iplImg->origin == IPL_ORIGIN_TL )
                    frame.copyTo( frameCopy );
                else
                    flip( frame, frameCopy, 0 );
                
                if( waitKey( 10 ) >= 0 )
                    cvReleaseCapture( &capture );
                
                cv::Mat InImage(frame);
                
                //Ok, let's detect
                MDetector.detect(InImage,Markers,CamParam,MarkerSize);
                //for each marker, draw info and its boundaries in the image
//                cout<<"size:"<<Markers.size()<<endl;
                
                for (unsigned int i=0;i<Markers.size();i++) {
                    cout<<Markers[i]<<endl;
                    Markers[i].draw(InImage,Scalar(0,0,255),2);
                    
                    if (!isDetected) {
                        cout << "Detecte Marker" << endl;
                        [((ASAppDelegate *)[NSApp delegate]) detectMarkerId:Markers[i].id];
                        isDetected = YES;
                    }
                }
                //                //draw a 3d cube in each marker if there is 3d info
                if (  CamParam.isValid() && MarkerSize!=-1) {
                    for (unsigned int i=0;i<Markers.size();i++) {
                        CvDrawingUtils::draw3dCube(InImage,Markers[i],CamParam);
                    }
                }
                //show input with augmented information
                cv::imshow("Marker Detector",InImage);
                //show also the internal image resulting from the threshold operation
                //                cv::imshow("thes", MDetector.getThresholdedImage() );
                //                cv::waitKey(0);//wait for key to be pressed
                
            }
            
            waitKey(0);
            
            cvDestroyWindow("Marker Detector");
            
        }
        
    } catch (std::exception &ex)
    
    {
        cout<<"Exception :"<<ex.what()<<endl;
    }
    
}

@end
