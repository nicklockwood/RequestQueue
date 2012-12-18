//
//  ViewController.m
//  BasicAuth
//
//  Created by Nick Lockwood on 17/05/2012.
//  Copyright (c) 2012 Charcoal Design. All rights reserved.
//

#import "ViewController.h"
#import "RequestQueue.h"


@interface ViewController () <UIAlertViewDelegate>

@property (nonatomic) NSURLAuthenticationChallenge *challenge;

@end


@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    //set up request for protected resource
    NSURL *URL = [NSURL URLWithString:@"http://www.charcoaldesign.co.uk/RequestQueue/Auth/IMG_0351.jpg"];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    RQOperation *operation = [RQOperation operationWithRequest:request];
    
    //add auth handler
    operation.authenticationChallengeHandler = ^(NSURLAuthenticationChallenge *challenge)
    {
        _challenge = challenge;
        [[[UIAlertView alloc] initWithTitle:@"Challenge Receiver" message:@"Send credentials?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Send", nil] show];
        
    };
    
    //add response handler
    operation.completionHandler = ^(NSURLResponse *response, NSData *data, NSError *error)
    {
        if (error)
        {
            [[[UIAlertView alloc] initWithTitle:@"Error" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        }
        else
        {
            //set image
            _imageView.image = [UIImage imageWithData:data];
        }
    };
    
    //make request
    [[RequestQueue mainQueue] addOperation:operation];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == alertView.cancelButtonIndex)
    {
        //don't send credentials
        [_challenge.sender continueWithoutCredentialForAuthenticationChallenge:_challenge];
    }
    else
    {
        //construct credential
        NSURLCredential *credential = [NSURLCredential credentialWithUser:@"test"
                                                                 password:@"test"
                                                              persistence:NSURLCredentialPersistenceNone];
        //send credential
        [_challenge.sender useCredential:credential forAuthenticationChallenge:_challenge];
    }
}

@end
