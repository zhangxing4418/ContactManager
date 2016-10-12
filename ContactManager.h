//
// ContactManager.h
// Project
//
// Created by Ziv on 16/10/11.
//
//

#import <Foundation/Foundation.h>
#import <OHABAddressBookContactsDataProvider.h>
#import <OHCNContactsDataProvider.h>

typedef NS_ENUM (NSUInteger, ContactSelectType) {
	ContactSelectNone = 0,
	ContactSelectPhoneNumber,
	ContactSelectEmailAddress,
	ContactSelectURL,
	ContactSelectPostalAddresses
};

@interface ContactManager : NSObject

+ (void)selectType:(ContactSelectType)selectType completion:(void (^) (OHContact *contact))block;

@end
