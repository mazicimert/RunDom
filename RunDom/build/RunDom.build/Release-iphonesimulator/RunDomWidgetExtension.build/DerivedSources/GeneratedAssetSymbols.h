#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"com.mertmazici.RunDom.RunDomWidget";

/// The "BoostGreen" asset catalog color resource.
static NSString * const ACColorNameBoostGreen AC_SWIFT_PRIVATE = @"BoostGreen";

/// The "BoostRed" asset catalog color resource.
static NSString * const ACColorNameBoostRed AC_SWIFT_PRIVATE = @"BoostRed";

/// The "BoostYellow" asset catalog color resource.
static NSString * const ACColorNameBoostYellow AC_SWIFT_PRIVATE = @"BoostYellow";

/// The "CardBackground" asset catalog color resource.
static NSString * const ACColorNameCardBackground AC_SWIFT_PRIVATE = @"CardBackground";

/// The "SurfacePrimary" asset catalog color resource.
static NSString * const ACColorNameSurfacePrimary AC_SWIFT_PRIVATE = @"SurfacePrimary";

/// The "TerritoryBlue" asset catalog color resource.
static NSString * const ACColorNameTerritoryBlue AC_SWIFT_PRIVATE = @"TerritoryBlue";

/// The "TerritoryRed" asset catalog color resource.
static NSString * const ACColorNameTerritoryRed AC_SWIFT_PRIVATE = @"TerritoryRed";

/// The "google_logo" asset catalog image resource.
static NSString * const ACImageNameGoogleLogo AC_SWIFT_PRIVATE = @"google_logo";

/// The "welcome_character" asset catalog image resource.
static NSString * const ACImageNameWelcomeCharacter AC_SWIFT_PRIVATE = @"welcome_character";

#undef AC_SWIFT_PRIVATE
