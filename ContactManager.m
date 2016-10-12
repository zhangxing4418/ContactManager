//
// ContactManager.m
// Project
//
// Created by Ziv on 16/10/11.
//
//

#import "ContactManager.h"
#import "CocoaUtils.h"
@import ContactsUI;
@import AddressBookUI;

@interface ContactManager () <CNContactPickerDelegate, OHCNContactsDataProviderDelegate, ABPeoplePickerNavigationControllerDelegate, OHABAddressBookContactsDataProviderDelegate>

@property (nonatomic, strong) UIViewController *viewController;
@property (nonatomic, strong) OHCNContactsDataProvider *contactProvider;
@property (nonatomic, strong) OHABAddressBookContactsDataProvider *abAddressProvider;
@property (nonatomic, assign) ContactSelectType selectType;

@property (nonatomic, copy) void (^doneBlock) (OHContact *contact);
@property (nonatomic, copy) void (^cancelBlock) (void);

@end

@implementation ContactManager

- (instancetype)initWithContactSelectType:(ContactSelectType)selectType {
	if ([super init]) {
		self.selectType = selectType;
		self.contactProvider = [[OHCNContactsDataProvider alloc] initWithDelegate:self];
		self.abAddressProvider = [[OHABAddressBookContactsDataProvider alloc] initWithDelegate:self];
		[self configContact];
	}
	return self;
}

#pragma mark - Public

+ (instancetype)shardedInstance {
	static ContactManager *_sharedInstance;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_sharedInstance = [[self alloc] initWithContactSelectType:ContactSelectNone];
	});
	return _sharedInstance;
}

+ (void)selectType:(ContactSelectType)selectType completion:(void (^) (OHContact *contact))block {
	ContactManager *manager = [ContactManager shardedInstance];
	[manager setDoneBlock:block];
	[manager setCancelBlock:nil];
	manager.selectType = selectType;
	[manager show];
}

#pragma mark - protect

- (void)setSelectType:(ContactSelectType)selectType {
	_selectType = selectType;
	[self configContact];
}

#pragma mark - Private

- (void)show {
	UIViewController *this = [CocoaUtils topMostViewController];
	[this presentViewController:self.viewController animated:YES completion:nil];
}

- (void)configContact {
	Class class = NSClassFromString(@"CNContactPickerViewController");
	if (class) {
		CNContactPickerViewController *contactVC = [[CNContactPickerViewController alloc] init];
		contactVC.delegate = self;
		switch (self.selectType) {
			case ContactSelectPhoneNumber:
				contactVC.displayedPropertyKeys = @[CNContactPhoneNumbersKey];
				contactVC.predicateForSelectionOfContact = [NSPredicate predicateWithValue:FALSE];
				break;

			case ContactSelectEmailAddress:
				contactVC.displayedPropertyKeys = @[CNContactEmailAddressesKey];
				contactVC.predicateForSelectionOfContact = [NSPredicate predicateWithValue:FALSE];
				break;

			case ContactSelectURL:
				contactVC.displayedPropertyKeys = @[CNContactUrlAddressesKey];
				contactVC.predicateForSelectionOfContact = [NSPredicate predicateWithValue:FALSE];
				break;

			case ContactSelectPostalAddresses:
				contactVC.displayedPropertyKeys = @[CNContactPostalAddressesKey];
				contactVC.predicateForSelectionOfContact = [NSPredicate predicateWithValue:FALSE];
				break;

			default:
				contactVC.displayedPropertyKeys = @[CNContactEmailAddressesKey,
				CNContactPhoneNumbersKey,
				CNContactUrlAddressesKey,
				CNContactPostalAddressesKey,
				CNContactOrganizationNameKey,
				CNContactJobTitleKey,
				CNContactDepartmentNameKey];
				contactVC.predicateForSelectionOfContact = [NSPredicate predicateWithValue:TRUE];
				break;
		}
		self.viewController = contactVC;
	} else {
		ABPeoplePickerNavigationController *pickerController = [[ABPeoplePickerNavigationController alloc] init];
		pickerController.peoplePickerDelegate = self;
		switch (self.selectType) {
			case ContactSelectPhoneNumber:
				pickerController.displayedProperties = @[@(kABPersonPhoneProperty)];
				pickerController.predicateForSelectionOfPerson = [NSPredicate predicateWithValue:FALSE];
				break;

			case ContactSelectEmailAddress:
				pickerController.displayedProperties = @[@(kABPersonEmailProperty)];
				pickerController.predicateForSelectionOfPerson = [NSPredicate predicateWithValue:FALSE];
				break;

			case ContactSelectURL:
				pickerController.displayedProperties = @[@(kABPersonURLProperty)];
				pickerController.predicateForSelectionOfPerson = [NSPredicate predicateWithValue:FALSE];
				break;

			case ContactSelectPostalAddresses:
				pickerController.displayedProperties = @[@(kABPersonAddressProperty)];
				pickerController.predicateForSelectionOfPerson = [NSPredicate predicateWithValue:FALSE];
				break;

			default:
				pickerController.displayedProperties = @[@(kABPersonEmailProperty),
				@(kABPersonPhoneProperty),
				@(kABPersonURLProperty),
				@(kABPersonAddressProperty),
				@(kABPersonOrganizationProperty),
				@(kABPersonJobTitleProperty),
				@(kABPersonDepartmentProperty)];
				pickerController.predicateForSelectionOfPerson = [NSPredicate predicateWithValue:TRUE];
				break;
		}
		self.viewController = pickerController;
	}
}

- (OHContactFieldType)transformToOHContactFieldTypeWithPropertyKey:(NSString *)key {
	if ([key isEqualToString:@"phoneNumbers"]) {
		return OHContactFieldTypePhoneNumber;
	} else if ([key isEqualToString:@"emailAddresses"]) {
		return OHContactFieldTypeEmailAddress;
	} else if ([key isEqualToString:@"urlAddresses"]) {
		return OHContactFieldTypeURL;
	} else {
		return OHContactFieldTypeOther;
	}
}

- (OHContactFieldType)transformToOHContactFieldTypeWithProperty:(ABPropertyID)property {
	if (property == kABPersonPhoneProperty) {
		return OHContactFieldTypePhoneNumber;
	} else if (property == kABPersonEmailProperty) {
		return OHContactFieldTypeEmailAddress;
	} else if (property == kABPersonURLProperty) {
		return OHContactFieldTypeURL;
	} else {
		return OHContactFieldTypeOther;
	}
}

#pragma mark - CNContactPickerDelegate

- (void)contactPickerDidCancel:(CNContactPickerViewController *)picker {
	if (self.cancelBlock) {
		self.cancelBlock();
	}
}

- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContact:(CNContact *)contact {
	OHContact *ohContact = [self.contactProvider performSelector:@selector(_contactForCNContact:) withObject:contact];
	if (self.doneBlock) {
		self.doneBlock(ohContact);
	}
}

- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContactProperty:(CNContactProperty *)contactProperty {

	OHContact *contact = [[OHContact alloc] init];
	contact.firstName = contactProperty.contact.givenName;
	contact.lastName = contactProperty.contact.familyName;
	if ([contactProperty.key isEqualToString:@"postalAddresses"]) {
		OHContactAddress *contactAddress = [[OHContactAddress alloc] initWithLabel:contactProperty.label street:[contactProperty.value street] city:[contactProperty.value city] state:[(CNPostalAddress *) contactProperty.value state] postalCode:[contactProperty.value postalCode] country:[contactProperty.value country] dataProviderIdentifier:NSStringFromClass([OHCNContactsDataProvider class])];
		NSOrderedSet *contactAddressSet = [NSOrderedSet orderedSetWithObject:contactAddress];
		contact.postalAddresses = contactAddressSet;
	} else {
		OHContactField *contactField = [[OHContactField alloc] initWithType:[self transformToOHContactFieldTypeWithPropertyKey:contactProperty.key] label:contactProperty.label value:[contactProperty.key isEqualToString:@"phoneNumbers"] ? [contactProperty.value stringValue] : contactProperty.value dataProviderIdentifier:NSStringFromClass([OHCNContactsDataProvider class])];
		NSOrderedSet *contactFieldSet = [NSOrderedSet orderedSetWithObject:contactField];
		contact.contactFields = contactFieldSet;
	}

	if (self.doneBlock) {
		self.doneBlock(contact);
	}
}

#pragma mark - ABPeoplePickerNavigationControllerDelegate

- (void)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker didSelectPerson:(ABRecordRef)person {
	OHContact *contact = [self.abAddressProvider performSelector:@selector(_transformABRecordToOHContactWithRecord:) withObject:(__bridge id)(person)];
	if (self.doneBlock) {
		self.doneBlock(contact);
	}
}

- (void)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker didSelectPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier {
	OHContact *contact = [self.abAddressProvider performSelector:@selector(_transformABRecordToOHContactWithRecord:) withObject:(__bridge id)(person)];

	ABMultiValueRef multiValue = ABRecordCopyValue(person, property);
	long index = ABMultiValueGetIndexForIdentifier(multiValue, identifier);
	NSString *label = nil;
	CFStringRef rawLabel = ABMultiValueCopyLabelAtIndex(multiValue, index);
	if (rawLabel) {
		label = (__bridge_transfer NSString *)ABAddressBookCopyLocalizedLabel(rawLabel);
		CFRelease(rawLabel);
	}
	if (property == kABPersonAddressProperty) {
		NSDictionary *value = (__bridge NSDictionary *)ABMultiValueCopyValueAtIndex(multiValue, index);
		OHContactAddress *contactAddress = [[OHContactAddress alloc] initWithLabel:label street:value[@"Street"] city:value[@"City"] state:value[@"State"] postalCode:value[@"ZIP"] country:value[@"Country"] dataProviderIdentifier:NSStringFromClass([OHABAddressBookContactsDataProvider class])];
		NSOrderedSet *contactAddressSet = [NSOrderedSet orderedSetWithObject:contactAddress];
		contact.postalAddresses = contactAddressSet;
	} else {
		NSString *value = (__bridge NSString *)ABMultiValueCopyValueAtIndex(multiValue, index);
		OHContactField *contactField = [[OHContactField alloc] initWithType:[self transformToOHContactFieldTypeWithProperty:property] label:label value:value dataProviderIdentifier:NSStringFromClass([OHABAddressBookContactsDataProvider class])];
		NSOrderedSet *contactFieldSet = [NSOrderedSet orderedSetWithObject:contactField];
		contact.contactFields = contactFieldSet;
	}
	CFRelease(multiValue);
	if (self.doneBlock) {
		self.doneBlock(contact);
	}
}

- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker {
	if (self.cancelBlock) {
		self.cancelBlock();
	}
}

#pragma mark - OHCNContactsDataProviderDelegate

- (void)dataProviderDidHitContactsAuthenticationChallenge:(OHCNContactsDataProvider *)dataProvider {
}

#pragma mark - OHABAddressBookContactsDataProviderDelegate

- (void)dataProviderDidHitAddressBookAuthenticationChallenge:(OHABAddressBookContactsDataProvider *)dataProvider {
}

@end
