//
//  SecondViewController.m
//  dip
//
//  Created by Joe Yang on 2018-03-19.
//  Copyright © 2018 Joe Yang. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "CameraViewController.h"

@interface CameraViewController () <UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UIView *videoStream;
@property (weak, nonatomic) IBOutlet UIButton *rotateNameButton;
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UIButton *rotateMonthButton;

@property(nonatomic) AVCaptureSession *session;


@property(nonatomic) UIView *firstInfo;

@property(nonatomic) UILabel *firstName;
@property(nonatomic) UILabel *firstBirth;
@property(nonatomic) UILabel *firstColour;


@property(nonatomic) UIView *secondInfo;

@property(nonatomic) UILabel *secondName;
@property(nonatomic) UILabel *secondBirth;
@property(nonatomic) UILabel *secondColour;

@property(nonatomic) UIView *thirdInfo;

@property(nonatomic) UILabel *thirdName;
@property(nonatomic) UILabel *thirdBirth;
@property(nonatomic) UILabel *thirdColour;

@property(nonatomic) UIView *fourthInfo;

@property(nonatomic) UILabel *fourthName;
@property(nonatomic) UILabel *fourthBirth;
@property(nonatomic) UILabel *fourthColour;

@end

@implementation CameraViewController

- (IBAction)rotateNames {
  NSString *text = _firstName.text;
  UIColor *textColor = _firstName.textColor;
  _firstName.text = _secondName.text;
  _firstName.textColor = _secondName.textColor;
  _secondName.text = _fourthName.text;
  _secondName.textColor = _fourthName.textColor;
  _fourthName.text = _thirdName.text;
  _fourthName.textColor = _thirdName.textColor;
  _thirdName.text = text;
  _thirdName.textColor = textColor;
  [_firstName sizeToFit];
  [_secondName sizeToFit];
  [_thirdName sizeToFit];
  [_fourthName sizeToFit];
  return;
}
- (IBAction)rotateMonths:(id)sender {
  NSString *text = _firstBirth.text;
  _firstBirth.text = _thirdBirth.text;
  _thirdBirth.text = _fourthBirth.text;
  _fourthBirth.text = _secondBirth.text;
  _secondBirth.text = text;
  [_firstBirth sizeToFit];
  [_secondBirth sizeToFit];
  [_thirdBirth sizeToFit];
  [_fourthBirth sizeToFit];
  return;
}
- (IBAction)sendAnswer:(id)sender {
  if ([_textField.text isEqualToString: @"100"]) {
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:@"Correct!"
                                 message:@"Please present the same amount of faces as Alice's day of birth."
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

- (void)viewWillAppear:(BOOL)animated {
  [_session startRunning];
}
- (void)startVideoStream {
  _session = [[AVCaptureSession alloc] init];
  AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
  AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
  [_session addInput:input];
  [_session startRunning];
  AVCaptureVideoPreviewLayer *previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
  NSLog(@"%f", previewLayer.frame.size.width);
  previewLayer.frame = CGRectMake(24, 0, _videoStream.frame.size.width, _videoStream.frame.size.width);
  [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
  [self.view sendSubviewToBack:_videoStream];
  [_videoStream.layer addSublayer:previewLayer];
  [_videoStream setFrame:CGRectMake(_videoStream.frame.origin.x, _videoStream.frame.origin.y, previewLayer.frame.size.width, previewLayer.frame.size.height)];
  CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(input.device.activeFormat.formatDescription);
  NSLog(@"Width:%f Height:%f", previewLayer.frame.size.width, previewLayer.frame.size.height);
  
  
}

- (void)initializeViews {
  [_rotateNameButton addTarget:self action:@selector(rotateNames) forControlEvents:UIControlEventTouchUpInside];
  
  CGRect videoRect = _videoStream.frame;
  CGFloat videoFrameX = videoRect.origin.x;
  CGFloat videoFrameY = videoRect.origin.y;
  CGFloat videoFrameWidth = _videoStream.frame.size.width;
  CGFloat videoFrameHeight = _videoStream.frame.size.height;
  
  _firstName = [[UILabel alloc] initWithFrame:CGRectMake(videoFrameX+ 64, videoFrameY, 0, 0)];
  _secondName = [[UILabel alloc] initWithFrame:CGRectMake(videoFrameX + videoFrameWidth/2 + 96, videoFrameY, 0, 0)];
  _thirdName = [[UILabel alloc] initWithFrame:CGRectMake(videoFrameX + 64, videoFrameY + videoFrameHeight/2, 0, 0)];
  _fourthName = [[UILabel alloc] initWithFrame:CGRectMake(videoFrameX + videoFrameWidth/2 + 96, videoFrameY + videoFrameHeight/2, 0, 0)];
  
  [_videoStream addSubview:_firstName];
  [_videoStream addSubview:_secondName];
  [_videoStream addSubview:_thirdName];
  [_videoStream addSubview:_fourthName];
  
  [_firstName setText:@"Bob"];
  _firstName.textColor = [UIColor redColor];
  [_firstName sizeToFit];
  [_secondName setText:@"Mary"];
  [_secondName sizeToFit];
  _secondName.textColor = [UIColor blueColor];
  [_thirdName setText:@"Alice"];
  [_thirdName sizeToFit];
  _thirdName.textColor = [UIColor greenColor];
  [_fourthName setText:@"John"];
  [_fourthName sizeToFit];
  _fourthName.textColor = [UIColor yellowColor];
  
  _firstBirth = [[UILabel alloc] initWithFrame:CGRectOffset(_firstName.frame, 0, 48)];
  _secondBirth = [[UILabel alloc] initWithFrame:CGRectOffset(_secondName.frame, 0, 48)];
  _thirdBirth = [[UILabel alloc] initWithFrame:CGRectOffset(_thirdName.frame, 0, 48)];
  _fourthBirth = [[UILabel alloc] initWithFrame:CGRectOffset(_fourthName.frame, 0, 48)];
  
  [_firstBirth setText:@"January"];
  [_firstBirth sizeToFit];
  [_secondBirth setText:@"March"];
  [_secondBirth sizeToFit];
  [_thirdBirth setText:@"October"];
  [_thirdBirth sizeToFit];
  [_fourthBirth setText:@"December"];
  [_fourthBirth sizeToFit];
  
  [_videoStream addSubview:_firstBirth];
  [_videoStream addSubview:_secondBirth];
  [_videoStream addSubview:_thirdBirth];
  [_videoStream addSubview:_fourthBirth];
}

- (void)dismissKeyboard {
  [_textField resignFirstResponder];
}


- (void)keyboardDidShow:(NSNotification *)notification
{
  // Assign new frame to your view
  [self.view setFrame:CGRectMake(0,-110,320,460)];
  
}

-(void)keyboardDidHide:(NSNotification *)notification
{
  [self.view setFrame:CGRectMake(0,0,320,460)];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  [self startVideoStream];
  [self initializeViews];
  UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                        action:@selector(dismissKeyboard)];
  [_textField setDelegate:self];
  [self.view addGestureRecognizer:tap];
  
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}


@end
