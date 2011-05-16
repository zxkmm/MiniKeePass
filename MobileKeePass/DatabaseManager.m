//
//  DatabaseManager.m
//  MobileKeePass
//
//  Created by Jason Rush on 5/9/11.
//  Copyright 2011 Self. All rights reserved.
//

#import "DatabaseManager.h"
#import "MobileKeePassAppDelegate.h"
#import "SFHFKeychainUtils.h"
#import "PasswordEntryController.h"

@implementation DatabaseManager

@synthesize selectedPath;
@synthesize animated;

static DatabaseManager *sharedInstance;

+ (void)initialize {
    static BOOL initialized = NO;
    if (!initialized)     {
        initialized = YES;
        sharedInstance = [[DatabaseManager alloc] init];
    }
}

+ (DatabaseManager*)sharedInstance {
    return sharedInstance;
}

- (void)dealloc {
    [selectedPath release];
    [super dealloc];
}

- (void)openDatabaseDocument:(NSString*)path animated:(BOOL)newAnimated {
    BOOL databaseLoaded = NO;
    
    self.selectedPath = path;
    self.animated = newAnimated;
    
    // Load the password from the keychain
    NSString *password = [SFHFKeychainUtils getPasswordForUsername:path andServiceName:@"net.fizzawizza.MobileKeePass.passwords" error:nil];
    
    // Get the application delegate
    MobileKeePassAppDelegate *appDelegate = (MobileKeePassAppDelegate*)[[UIApplication sharedApplication] delegate];
    
    // Try and load the database with the cached password from the keychain
    if (password != nil) {
        // Load the database
        DatabaseDocument *dd = [[DatabaseDocument alloc] init];
        
        @try {
            [dd open:path password:password];
            
            databaseLoaded = YES;
            
            // Set the database document in the application delegate
            appDelegate.databaseDocument = dd;
            
            // Store the filename as the last opened database
            NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
            [userDefaults setValue:path forKey:@"lastFilename"];
        } @catch (NSException * exception) {
        }
        
        [dd release];
    }
    
    // Prompt the user for the password if we haven't loaded the database yet
    if (!databaseLoaded) {
        // Prompt the user for a password
        PasswordEntryController *passwordEntryController = [[PasswordEntryController alloc] init];
        passwordEntryController.delegate = self;
        [appDelegate.window.rootViewController presentModalViewController:passwordEntryController animated:animated];
        [passwordEntryController release];
    }
}

- (void)loadDatabaseDocument:(DatabaseDocument*)databaseDocument {
    // Set the database document in the application delegate
    MobileKeePassAppDelegate *appDelegate = (MobileKeePassAppDelegate*)[[UIApplication sharedApplication] delegate];
    appDelegate.databaseDocument = databaseDocument;
    
    [databaseDocument release];
}

- (BOOL)passwordEntryController:(PasswordEntryController*)controller passwordEntered:(NSString*)password {
    BOOL shouldDismiss = YES;
    
    // Load the database
    DatabaseDocument *dd = [[DatabaseDocument alloc] init];
    
    @try {
        // Open the database
        [dd open:selectedPath password:password];
        
        // Store the filename as the last opened database
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setValue:selectedPath forKey:@"lastFilename"];
        
        // Store the password in the keychain
        if ([userDefaults boolForKey:@"rememberPasswordsEnabled"]) {
            NSError *error;
            [SFHFKeychainUtils storeUsername:selectedPath andPassword:password forServiceName:@"net.fizzawizza.MobileKeePass.passwords" updateExisting:YES error:&error];
        }

        // Load the database after a short delay so the push animation is visible
        [self performSelector:@selector(loadDatabaseDocument:) withObject:dd afterDelay:0.01];
    } @catch (NSException *exception) {
        shouldDismiss = NO;
        controller.statusLabel.text = exception.reason;
        [dd release];
    }
    
    return shouldDismiss;
}

- (void)passwordEntryControllerCancelButtonPressed:(PasswordEntryController *)controller {
    [controller dismissModalViewControllerAnimated:YES];
}

@end
