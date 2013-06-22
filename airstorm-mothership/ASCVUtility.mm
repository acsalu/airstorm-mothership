//
//  ASCVUtility.m
//  airstorm-mothership
//
//  Created by Acsa Lu on 6/22/13.
//  Copyright (c) 2013 com.nmlab-g7. All rights reserved.
//

#import "ASCVUtility.h"
#include "opencv2/core/core.hpp"
#include "opencv2/imgproc/imgproc.hpp"
#include "opencv2/calib3d/calib3d.hpp"
#include "opencv2/highgui/highgui.hpp"

#include <cctype>
#include <stdio.h>
#include <string.h>
#include <time.h>

using namespace cv;
using namespace std;

enum { DETECTION = 0, CAPTURING = 1, CALIBRATED = 2 };
enum CVPattern { CHESSBOARD, CIRCLES_GRID, ASYMMETRIC_CIRCLES_GRID };

static double computeReprojectionErrors(const vector<vector<Point3f> >&, const vector<vector<Point2f> >&,
                                        const vector<Mat>&, const vector<Mat>&, const Mat&, const Mat&, vector<float>&);
static void calcChessboardCorners(cv::Size, float, vector<Point3f>&, CVPattern);
static bool runCalibration( vector<vector<Point2f> >, cv::Size, cv::Size, CVPattern, float, float,
                           int, Mat&, Mat&, vector<Mat>&, vector<Mat>&, vector<float>&, double&);
static void saveCameraParams(const string&, cv::Size, cv::Size, float, float, int, const Mat&, const Mat&,
                             const vector<Mat>&, const vector<Mat>&, const vector<float>&, const vector<vector<Point2f> >&, double);
static bool readStringList(const string&, vector<string>&);
static bool runAndSave(const string&, const vector<vector<Point2f> >&, cv::Size, cv::Size, CVPattern, float,
                       float, int, Mat&, Mat&, bool, bool);


@implementation ASCVUtility

+ (void)calibrate
{
    NSLog(@"Calibrating camera...");
    
    cv::Size boardSize, imageSize;
    float squareSize = 1.f, aspectRatio = 1.f;
    Mat cameraMatrix, distCoeffs;
    const char* outputFilename = "/tmp/airtorm-camarea-calibration.yml";
    const char* inputFilename = 0;
    
    int i, nframes = 10;
    bool writeExtrinsics = false, writePoints = false;
    bool undistortImage = false;
    int flags = 0;
    VideoCapture capture;
    bool flipVertical = false;
    bool showUndistorted = false;
    bool videofile = false;
    int delay = 1000;
    clock_t prevTimestamp = 0;
    int mode = DETECTION;
    int cameraId = 0;
    vector<vector<Point2f> > imagePoints;
    vector<string> imageList;
    CVPattern pattern = CHESSBOARD;
    
    boardSize.width = 7;
    boardSize.height = 7;
    
    squareSize = 0.025;
    
    capture.open(cameraId);
    
    if( !capture.isOpened() && imageList.empty() ) {
        NSLog(@"Calibration Error: Could not initialize video (%d) capture",cameraId);
        return;
    }
    
    if( !imageList.empty() )
        nframes = (int)imageList.size();
    
    namedWindow("Calibration View", 1);
    
    for(i = 0;;i++)
    {
        Mat view, viewGray;
        bool blink = false;
        
        if( capture.isOpened() )
        {
            Mat view0;
            capture >> view0;
            view0.copyTo(view);
        }
        else if( i < (int)imageList.size() )
            view = imread(imageList[i], 1);
        
        if(!view.data)
        {
            if( imagePoints.size() > 0 )
                runAndSave(outputFilename, imagePoints, imageSize,
                           boardSize, pattern, squareSize, aspectRatio,
                           flags, cameraMatrix, distCoeffs,
                           writeExtrinsics, writePoints);
            break;
        }
        
        imageSize = view.size();
        
        if( flipVertical )
            flip( view, view, 0 );
        
        vector<Point2f> pointbuf;
        cvtColor(view, viewGray, CV_BGR2GRAY);
        
        bool found;
        switch( pattern )
        {
            case CHESSBOARD:
                found = findChessboardCorners( view, boardSize, pointbuf,
                                              CV_CALIB_CB_ADAPTIVE_THRESH | CV_CALIB_CB_FAST_CHECK | CV_CALIB_CB_NORMALIZE_IMAGE);
                break;
            case CIRCLES_GRID:
                found = findCirclesGrid( view, boardSize, pointbuf );
                break;
            case ASYMMETRIC_CIRCLES_GRID:
                found = findCirclesGrid( view, boardSize, pointbuf, CALIB_CB_ASYMMETRIC_GRID );
                break;
            default:
                NSLog(@"Calibration Error: Unkown pattern type");
                return;
        }
        
        // improve the found corners' coordinate accuracy
        if( pattern == CHESSBOARD && found) cornerSubPix( viewGray, pointbuf, cv::Size(11,11),
                                                         cv::Size(-1,-1), TermCriteria( CV_TERMCRIT_EPS+CV_TERMCRIT_ITER, 30, 0.1 ));
        
        if( mode == CAPTURING && found &&
           (!capture.isOpened() || clock() - prevTimestamp > delay*1e-3*CLOCKS_PER_SEC) )
        {
            imagePoints.push_back(pointbuf);
            prevTimestamp = clock();
            blink = capture.isOpened();
        }
        
        if(found)
            drawChessboardCorners( view, boardSize, Mat(pointbuf), found );
        
        string msg = mode == CAPTURING ? "100/100" :
        mode == CALIBRATED ? "Calibrated" : "Press 'g' to start";
        int baseLine = 0;
        cv::Size textSize = getTextSize(msg, 1, 1, 1, &baseLine);
        cv::Point textOrigin(view.cols - 2*textSize.width - 10, view.rows - 2*baseLine - 10);
        
        if( mode == CAPTURING )
        {
            if(undistortImage)
                msg = format( "%d/%d Undist", (int)imagePoints.size(), nframes );
            else
                msg = format( "%d/%d", (int)imagePoints.size(), nframes );
        }
        
        putText( view, msg, textOrigin, 1, 1,
                mode != CALIBRATED ? Scalar(0,0,255) : Scalar(0,255,0));
        
        if( blink )
            bitwise_not(view, view);
        
        if( mode == CALIBRATED && undistortImage )
        {
            Mat temp = view.clone();
            undistort(temp, view, cameraMatrix, distCoeffs);
        }
        
        imshow("Calibration View", view);
        int key = 0xff & waitKey(capture.isOpened() ? 50 : 500);
        
        if( (key & 255) == 27 )
            break;
        
        if( key == 'u' && mode == CALIBRATED )
            undistortImage = !undistortImage;
        
        if( capture.isOpened() && key == 'g' )
        {
            mode = CAPTURING;
            imagePoints.clear();
        }
        
        if( mode == CAPTURING && imagePoints.size() >= (unsigned)nframes )
        {
            if( runAndSave(outputFilename, imagePoints, imageSize,
                           boardSize, pattern, squareSize, aspectRatio,
                           flags, cameraMatrix, distCoeffs,
                           writeExtrinsics, writePoints))
                mode = CALIBRATED;
            else
                mode = DETECTION;
            if( !capture.isOpened() )
                break;
        }
    }
    
    if( !capture.isOpened() && showUndistorted )
    {
        Mat view, rview, map1, map2;
        initUndistortRectifyMap(cameraMatrix, distCoeffs, Mat(),
                                getOptimalNewCameraMatrix(cameraMatrix, distCoeffs, imageSize, 1, imageSize, 0),
                                imageSize, CV_16SC2, map1, map2);
        
        for( i = 0; i < (int)imageList.size(); i++ )
        {
            view = imread(imageList[i], 1);
            if(!view.data)
                continue;
            //undistort( view, rview, cameraMatrix, distCoeffs, cameraMatrix );
            remap(view, rview, map1, map2, INTER_LINEAR);
            imshow("Calibration View", rview);
            int c = 0xff & waitKey();
            if( (c & 255) == 27 || c == 'q' || c == 'Q' )
                break;
        }
    }
}


@end

static double computeReprojectionErrors(
                                        const vector<vector<Point3f> >& objectPoints,
                                        const vector<vector<Point2f> >& imagePoints,
                                        const vector<Mat>& rvecs, const vector<Mat>& tvecs,
                                        const Mat& cameraMatrix, const Mat& distCoeffs,
                                        vector<float>& perViewErrors )
{
    vector<Point2f> imagePoints2;
    int i, totalPoints = 0;
    double totalErr = 0, err;
    perViewErrors.resize(objectPoints.size());
    
    for( i = 0; i < (int)objectPoints.size(); i++ )
    {
        projectPoints(Mat(objectPoints[i]), rvecs[i], tvecs[i],
                      cameraMatrix, distCoeffs, imagePoints2);
        err = norm(Mat(imagePoints[i]), Mat(imagePoints2), CV_L2);
        int n = (int)objectPoints[i].size();
        perViewErrors[i] = (float)std::sqrt(err*err/n);
        totalErr += err*err;
        totalPoints += n;
    }
    
    return std::sqrt(totalErr/totalPoints);
}

static void calcChessboardCorners(cv::Size boardSize, float squareSize, vector<Point3f>& corners, CVPattern patternType = CHESSBOARD)
{
    corners.resize(0);
    
    switch(patternType)
    {
        case CHESSBOARD:
        case CIRCLES_GRID:
            for( int i = 0; i < boardSize.height; i++ )
                for( int j = 0; j < boardSize.width; j++ )
                    corners.push_back(Point3f(float(j*squareSize),
                                              float(i*squareSize), 0));
            break;
            
        case ASYMMETRIC_CIRCLES_GRID:
            for( int i = 0; i < boardSize.height; i++ )
                for( int j = 0; j < boardSize.width; j++ )
                    corners.push_back(Point3f(float((2*j + i % 2)*squareSize),
                                              float(i*squareSize), 0));
            break;
            
        default:
            CV_Error(CV_StsBadArg, "Unknown pattern type\n");
    }
}

static bool runCalibration( vector<vector<Point2f> > imagePoints,
                           cv::Size imageSize, cv::Size boardSize, CVPattern patternType,
                           float squareSize, float aspectRatio,
                           int flags, Mat& cameraMatrix, Mat& distCoeffs,
                           vector<Mat>& rvecs, vector<Mat>& tvecs,
                           vector<float>& reprojErrs,
                           double& totalAvgErr)
{
    cameraMatrix = Mat::eye(3, 3, CV_64F);
    if( flags & CV_CALIB_FIX_ASPECT_RATIO )
        cameraMatrix.at<double>(0,0) = aspectRatio;
    
    distCoeffs = Mat::zeros(8, 1, CV_64F);
    
    vector<vector<Point3f> > objectPoints(1);
    calcChessboardCorners(boardSize, squareSize, objectPoints[0], patternType);
    
    objectPoints.resize(imagePoints.size(),objectPoints[0]);
    
    double rms = calibrateCamera(objectPoints, imagePoints, imageSize, cameraMatrix,
                                 distCoeffs, rvecs, tvecs, flags|CV_CALIB_FIX_K4|CV_CALIB_FIX_K5);
    ///*|CV_CALIB_FIX_K3*/|CV_CALIB_FIX_K4|CV_CALIB_FIX_K5);
    printf("RMS error reported by calibrateCamera: %g\n", rms);
    
    bool ok = checkRange(cameraMatrix) && checkRange(distCoeffs);
    
    totalAvgErr = computeReprojectionErrors(objectPoints, imagePoints,
                                            rvecs, tvecs, cameraMatrix, distCoeffs, reprojErrs);
    
    return ok;
}


static void saveCameraParams( const string& filename,
                             cv::Size imageSize, cv::Size boardSize,
                             float squareSize, float aspectRatio, int flags,
                             const Mat& cameraMatrix, const Mat& distCoeffs,
                             const vector<Mat>& rvecs, const vector<Mat>& tvecs,
                             const vector<float>& reprojErrs,
                             const vector<vector<Point2f> >& imagePoints,
                             double totalAvgErr )
{
    FileStorage fs( filename, FileStorage::WRITE );
    
    time_t tt;
    time( &tt );
    struct tm *t2 = localtime( &tt );
    char buf[1024];
    strftime( buf, sizeof(buf)-1, "%c", t2 );
    
    fs << "calibration_time" << buf;
    
    if( !rvecs.empty() || !reprojErrs.empty() )
        fs << "nframes" << (int)std::max(rvecs.size(), reprojErrs.size());
    fs << "image_width" << imageSize.width;
    fs << "image_height" << imageSize.height;
    fs << "board_width" << boardSize.width;
    fs << "board_height" << boardSize.height;
    fs << "square_size" << squareSize;
    
    if( flags & CV_CALIB_FIX_ASPECT_RATIO )
        fs << "aspectRatio" << aspectRatio;
    
    if( flags != 0 )
    {
        sprintf( buf, "flags: %s%s%s%s",
                flags & CV_CALIB_USE_INTRINSIC_GUESS ? "+use_intrinsic_guess" : "",
                flags & CV_CALIB_FIX_ASPECT_RATIO ? "+fix_aspectRatio" : "",
                flags & CV_CALIB_FIX_PRINCIPAL_POINT ? "+fix_principal_point" : "",
                flags & CV_CALIB_ZERO_TANGENT_DIST ? "+zero_tangent_dist" : "" );
        cvWriteComment( *fs, buf, 0 );
    }
    
    fs << "flags" << flags;
    
    fs << "camera_matrix" << cameraMatrix;
    fs << "distortion_coefficients" << distCoeffs;
    
    fs << "avg_reprojection_error" << totalAvgErr;
    if( !reprojErrs.empty() )
        fs << "per_view_reprojection_errors" << Mat(reprojErrs);
    
    if( !rvecs.empty() && !tvecs.empty() )
    {
        CV_Assert(rvecs[0].type() == tvecs[0].type());
        Mat bigmat((int)rvecs.size(), 6, rvecs[0].type());
        for( int i = 0; i < (int)rvecs.size(); i++ )
        {
            Mat r = bigmat(Range(i, i+1), Range(0,3));
            Mat t = bigmat(Range(i, i+1), Range(3,6));
            
            CV_Assert(rvecs[i].rows == 3 && rvecs[i].cols == 1);
            CV_Assert(tvecs[i].rows == 3 && tvecs[i].cols == 1);
            //*.t() is MatExpr (not Mat) so we can use assignment operator
            r = rvecs[i].t();
            t = tvecs[i].t();
        }
        cvWriteComment( *fs, "a set of 6-tuples (rotation vector + translation vector) for each view", 0 );
        fs << "extrinsic_parameters" << bigmat;
    }
    
    if( !imagePoints.empty() )
    {
        Mat imagePtMat((int)imagePoints.size(), (int)imagePoints[0].size(), CV_32FC2);
        for( int i = 0; i < (int)imagePoints.size(); i++ )
        {
            Mat r = imagePtMat.row(i).reshape(2, imagePtMat.cols);
            Mat imgpti(imagePoints[i]);
            imgpti.copyTo(r);
        }
        fs << "image_points" << imagePtMat;
    }
}

static bool readStringList( const string& filename, vector<string>& l )
{
    l.resize(0);
    FileStorage fs(filename, FileStorage::READ);
    if( !fs.isOpened() )
        return false;
    FileNode n = fs.getFirstTopLevelNode();
    if( n.type() != FileNode::SEQ )
        return false;
    FileNodeIterator it = n.begin(), it_end = n.end();
    for( ; it != it_end; ++it )
        l.push_back((string)*it);
    return true;
}


static bool runAndSave(const string& outputFilename,
                       const vector<vector<Point2f> >& imagePoints,
                       cv::Size imageSize, cv::Size boardSize, CVPattern patternType, float squareSize,
                       float aspectRatio, int flags, Mat& cameraMatrix,
                       Mat& distCoeffs, bool writeExtrinsics, bool writePoints )
{
    vector<Mat> rvecs, tvecs;
    vector<float> reprojErrs;
    double totalAvgErr = 0;
    
    bool ok = runCalibration(imagePoints, imageSize, boardSize, patternType, squareSize,
                             aspectRatio, flags, cameraMatrix, distCoeffs,
                             rvecs, tvecs, reprojErrs, totalAvgErr);
    printf("%s. avg reprojection error = %.2f\n",
           ok ? "Calibration succeeded" : "Calibration failed",
           totalAvgErr);
    
    if( ok )
        saveCameraParams( outputFilename, imageSize,
                         boardSize, squareSize, aspectRatio,
                         flags, cameraMatrix, distCoeffs,
                         writeExtrinsics ? rvecs : vector<Mat>(),
                         writeExtrinsics ? tvecs : vector<Mat>(),
                         writeExtrinsics ? reprojErrs : vector<float>(),
                         writePoints ? imagePoints : vector<vector<Point2f> >(),
                         totalAvgErr );
    return ok;
}