#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import "FrontCamViewController.h"

static CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};

@interface FrontCamViewController () 
@property (weak, nonatomic) IBOutlet UIButton *captureButton;
@property(weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *facesLabel;
@property(nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property(nonatomic) AVCaptureSession *session;
@property(nonatomic) CIDetector *faceDetector;
@property(nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property(nonatomic) dispatch_queue_t videoDataOutputQueue;

@property(nonatomic) NSUInteger lastCount;
@end

@implementation FrontCamViewController

- (void)viewWillAppear:(BOOL)animated {
  [_session startRunning];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  NSDictionary *detectorOptions = [[NSDictionary alloc] initWithObjectsAndKeys:CIDetectorAccuracyLow, CIDetectorAccuracy, nil];
  self.faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];
  _session = [[AVCaptureSession alloc] init];
  if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone){
    [_session setSessionPreset:AVCaptureSessionPreset640x480];
  } else {
    [_session setSessionPreset:AVCaptureSessionPresetPhoto];
  }
  // Select a video device, make an input
  AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                               mediaType:AVMediaTypeVideo
                                                                position:AVCaptureDevicePositionFront];
  AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    // add the input to the session
  if ( [_session canAddInput:deviceInput] ){
    [_session addInput:deviceInput];
  }
  
  self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_session];
  self.previewLayer.backgroundColor = [[UIColor blackColor] CGColor];
  self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
  
  CALayer *rootLayer = [self.imageView layer];
  [rootLayer setMasksToBounds:YES];
  [self.previewLayer setFrame:[rootLayer bounds]];
  [rootLayer addSublayer:self.previewLayer];
  [_session startRunning];
  
  self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
  // we want BGRA, both CoreGraphics and OpenGL work well with 'BGRA'
  NSDictionary *rgbOutputSettings = [NSDictionary dictionaryWithObject:
                                     [NSNumber numberWithInt:kCMPixelFormat_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
  [self.videoDataOutput setVideoSettings:rgbOutputSettings];
  [self.videoDataOutput setAlwaysDiscardsLateVideoFrames:YES]; // discard if the data output queue is blocked
  // create a serial dispatch queue used for the sample buffer delegate
  // a serial dispatch queue must be used to guarantee that video frames will be delivered in order
  // see the header doc for setSampleBufferDelegate:queue: for more information
  self.videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
  [self.videoDataOutput setSampleBufferDelegate:self queue:self.videoDataOutputQueue];
  if ( [_session canAddOutput:self.videoDataOutput] ){
    [_session addOutput:self.videoDataOutput];
  }
  // get the output for doing face detection.
  [[self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
    
}
- (void)drawFaces:(NSArray *)features
      forVideoBox:(CGRect)clearAperture
      orientation:(UIDeviceOrientation)orientation
{
  NSArray *sublayers = [NSArray arrayWithArray:[self.previewLayer sublayers]];
  NSInteger sublayersCount = [sublayers count], currentSublayer = 0;
  NSInteger featuresCount = [features count], currentFeature = 0;
  
  [CATransaction begin];
  [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
  
  // hide all the face layers
  for ( CALayer *layer in sublayers ) {
    if ( [[layer name] isEqualToString:@"FaceLayer"] )
      [layer setHidden:YES];
  }
  
  if ( featuresCount == 0 ) {
    [CATransaction commit];
    return; // early bail.
  }
  
  CGSize parentFrameSize = [self.imageView frame].size;
  NSString *gravity = [self.previewLayer videoGravity];
  BOOL isMirrored = self.previewLayer.connection.isVideoMirrored;
  CGRect previewBox = [FrontCamViewController videoPreviewBoxForGravity:gravity
                                                      frameSize:parentFrameSize
                                                   apertureSize:clearAperture.size];
  
  for ( CIFaceFeature *ff in features ) {
    // find the correct position for the square layer within the previewLayer
    // the feature box originates in the bottom left of the video frame.
    // (Bottom right if mirroring is turned on)
    CGRect faceRect = [ff bounds];
    
    // flip preview width and height
    CGFloat temp = faceRect.size.width;
    faceRect.size.width = faceRect.size.height;
    faceRect.size.height = temp;
    temp = faceRect.origin.x;
    faceRect.origin.x = faceRect.origin.y;
    faceRect.origin.y = temp;
    // scale coordinates so they fit in the preview box, which may be scaled
    CGFloat widthScaleBy = previewBox.size.width / clearAperture.size.height;
    CGFloat heightScaleBy = previewBox.size.height / clearAperture.size.width;
    faceRect.size.width *= widthScaleBy;
    faceRect.size.height *= heightScaleBy;
    faceRect.origin.x *= widthScaleBy;
    faceRect.origin.y *= heightScaleBy;
    
    if ( isMirrored )
      faceRect = CGRectOffset(faceRect, previewBox.origin.x + previewBox.size.width - faceRect.size.width - (faceRect.origin.x * 2), previewBox.origin.y);
    else
      faceRect = CGRectOffset(faceRect, previewBox.origin.x, previewBox.origin.y);
    
    CALayer *featureLayer = nil;
    
    // re-use an existing layer if possible
    while ( !featureLayer && (currentSublayer < sublayersCount) ) {
      CALayer *currentLayer = [sublayers objectAtIndex:currentSublayer++];
      if ( [[currentLayer name] isEqualToString:@"FaceLayer"] ) {
        featureLayer = currentLayer;
        [currentLayer setHidden:NO];
      }
    }
    
    // create a new one if necessary
    if ( !featureLayer ) {
      featureLayer = [[CALayer alloc]init];
      featureLayer.borderColor = [UIColor redColor].CGColor;
      featureLayer.borderWidth = 1;
      [featureLayer setName:@"FaceLayer"];
      [self.previewLayer addSublayer:featureLayer];
      featureLayer = nil;
    }
    [featureLayer setFrame:faceRect];
    
    switch (orientation) {
      case UIDeviceOrientationPortrait:
        [featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(0.))];
        break;
      case UIDeviceOrientationPortraitUpsideDown:
        [featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(180.))];
        break;
      case UIDeviceOrientationLandscapeLeft:
        [featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(90.))];
        break;
      case UIDeviceOrientationLandscapeRight:
        [featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(-90.))];
        break;
      case UIDeviceOrientationFaceUp:
      case UIDeviceOrientationFaceDown:
      default:
        break; // leave the layer in its last known orientation
    }
    currentFeature++;
  }
  
  [CATransaction commit];
}
- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
  // get the image
  CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
  CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer
                                                    options:(__bridge NSDictionary *)attachments];
  if (attachments) {
    CFRelease(attachments);
  }
  
  // make sure your device orientation is not locked.
  UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
  
  NSDictionary *imageOptions = nil;
  
  imageOptions = [NSDictionary dictionaryWithObject:[self exifOrientation:curDeviceOrientation]
                                             forKey:CIDetectorImageOrientation];
  
  NSArray *features = [self.faceDetector featuresInImage:ciImage
                                                 options:imageOptions];
  _lastCount = [features count];
  
  // get the clean aperture
  // the clean aperture is a rectangle that defines the portion of the encoded pixel dimensions
  // that represents image data valid for display.
  CMFormatDescriptionRef fdesc = CMSampleBufferGetFormatDescription(sampleBuffer);
  CGRect cleanAperture = CMVideoFormatDescriptionGetCleanAperture(fdesc, false /*originIsTopLeft == false*/);
  
  dispatch_async(dispatch_get_main_queue(), ^(void) {
    [self drawFaces:features
        forVideoBox:cleanAperture
        orientation:curDeviceOrientation];
  });
}

- (NSNumber *) exifOrientation: (UIDeviceOrientation) orientation
{
  int exifOrientation;
  /* kCGImagePropertyOrientation values
   The intended display orientation of the image. If present, this key is a CFNumber value with the same value as defined
   by the TIFF and EXIF specifications -- see enumeration of integer constants.
   The value specified where the origin (0,0) of the image is located. If not present, a value of 1 is assumed.
   
   used when calling featuresInImage: options: The value for this key is an integer NSNumber from 1..8 as found in kCGImagePropertyOrientation.
   If present, the detection will be done based on that orientation but the coordinates in the returned features will still be based on those of the image. */
  
  enum {
    PHOTOS_EXIF_0ROW_TOP_0COL_LEFT      = 1, //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
    PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT      = 2, //   2  =  0th row is at the top, and 0th column is on the right.
    PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT      = 3, //   3  =  0th row is at the bottom, and 0th column is on the right.
    PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT       = 4, //   4  =  0th row is at the bottom, and 0th column is on the left.
    PHOTOS_EXIF_0ROW_LEFT_0COL_TOP          = 5, //   5  =  0th row is on the left, and 0th column is the top.
    PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP         = 6, //   6  =  0th row is on the right, and 0th column is the top.
    PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM      = 7, //   7  =  0th row is on the right, and 0th column is the bottom.
    PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM       = 8  //   8  =  0th row is on the left, and 0th column is the bottom.
  };
  
  switch (orientation) {
    case UIDeviceOrientationPortraitUpsideDown:  // Device oriented vertically, home button on the top
      exifOrientation = PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM;
      break;
    case UIDeviceOrientationLandscapeLeft:       // Device oriented horizontally, home button on the right
      exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
      break;
    case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
      exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
      break;
    case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
    default:
      exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP;
      break;
  }
  return [NSNumber numberWithInt:exifOrientation];
}

- (IBAction)captureImage:(id)sender {
  NSLog(@"%d", _lastCount);
  _facesLabel.text = [NSString stringWithFormat:@"%d", _lastCount];
  [_facesLabel sizeToFit];
  NSLog(@"%i", _lastCount);
  if (_lastCount == 3) {
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:@"Correct!"
                                 message:@"Play ."
                                 preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *actionOk = [UIAlertAction actionWithTitle:@"Ok"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    [alert addAction:actionOk];
    [self presentViewController:alert animated:YES completion:nil];
  } else {
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:@"Incorrect!"
                                 message:@"Please try again."
                                 preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *actionOk = [UIAlertAction actionWithTitle:@"Ok"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    [alert addAction:actionOk];
    [self presentViewController:alert animated:YES completion:nil];
  }
}

+ (CGRect)videoPreviewBoxForGravity:(NSString *)gravity
                          frameSize:(CGSize)frameSize
                       apertureSize:(CGSize)apertureSize
{
  CGFloat apertureRatio = apertureSize.height / apertureSize.width;
  CGFloat viewRatio = frameSize.width / frameSize.height;
  
  CGSize size = CGSizeZero;
  if ([gravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
    if (viewRatio > apertureRatio) {
      size.width = frameSize.width;
      size.height = apertureSize.width * (frameSize.width / apertureSize.height);
    } else {
      size.width = apertureSize.height * (frameSize.height / apertureSize.width);
      size.height = frameSize.height;
    }
  } else if ([gravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
    if (viewRatio > apertureRatio) {
      size.width = apertureSize.height * (frameSize.height / apertureSize.width);
      size.height = frameSize.height;
    } else {
      size.width = frameSize.width;
      size.height = apertureSize.width * (frameSize.width / apertureSize.height);
    }
  } else if ([gravity isEqualToString:AVLayerVideoGravityResize]) {
    size.width = frameSize.width;
    size.height = frameSize.height;
  }
  
  CGRect videoBox;
  videoBox.size = size;
  if (size.width < frameSize.width)
    videoBox.origin.x = (frameSize.width - size.width) / 2;
  else
    videoBox.origin.x = (size.width - frameSize.width) / 2;
  
  if ( size.height < frameSize.height )
    videoBox.origin.y = (frameSize.height - size.height) / 2;
  else
    videoBox.origin.y = (size.height - frameSize.height) / 2;
  
  return videoBox;
}


@end
