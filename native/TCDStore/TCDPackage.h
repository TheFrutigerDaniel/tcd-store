//
//  TCDPackage.h
//  TCD Store
//
//  One entry from a source index, plus whatever the local database knows
//  about whether it is installed. 10.7-compatible: no nullability
//  annotations, no generics, no modern lightweight generics.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, TCDPackageType) {
    TCDPackageTypeApp = 0,     // a .app bundle, installed to /Applications
    TCDPackageTypePkg,         // an Apple .pkg, installed with /usr/sbin/installer
    TCDPackageTypeKext,        // a kernel extension, copied to /System/Library/Extensions
    TCDPackageTypePrefPane     // a preference pane
};

typedef NS_OPTIONS(NSUInteger, TCDPackageArch) {
    TCDPackageArchAny    = 0,
    TCDPackageArchI386   = 1 << 0,
    TCDPackageArchX86_64 = 1 << 1
};

@interface TCDPackage : NSObject <NSCopying>

@property (nonatomic, copy)   NSString *identifier;      // stable id within a source
@property (nonatomic, copy)   NSString *sourceIdentifier;
@property (nonatomic, copy)   NSString *name;
@property (nonatomic, copy)   NSString *version;
@property (nonatomic, copy)   NSString *packageSummary;
@property (nonatomic, copy)   NSString *packageDescription;
@property (nonatomic, copy)   NSString *developer;
@property (nonatomic, copy)   NSString *section;
@property (nonatomic, copy)   NSString *changelog;
@property (nonatomic, copy)   NSString *iconURLString;
@property (nonatomic, copy)   NSString *downloadURLString;
@property (nonatomic, copy)   NSString *sha256;
@property (nonatomic, copy)   NSString *installPrefix;   // e.g. /Applications/Foo.app

@property (nonatomic, assign) TCDPackageType type;
@property (nonatomic, assign) TCDPackageArch  arch;
@property (nonatomic, assign) unsigned long long sizeBytes;
@property (nonatomic, assign) NSInteger ratingCount;
@property (nonatomic, assign) double  ratingAverage;
@property (nonatomic, copy)   NSString *minimumSystemVersion;  // "10.7"

@property (nonatomic, copy)   NSArray *dependencies;   // NSString identifiers
@property (nonatomic, copy)   NSArray *conflicts;      // NSString identifiers

// Local state, filled from the package database.
@property (nonatomic, assign) BOOL installed;
@property (nonatomic, copy)   NSString *installedVersion;
@property (nonatomic, assign) BOOL autoInstalled;   // pulled in only as a dependency
@property (nonatomic, copy)   NSString *receiptID;  // for .pkg

@property (nonatomic, readonly) BOOL hasUpdate;

+ (TCDPackageType)typeFromString:(NSString *)s;
+ (NSString *)stringForType:(TCDPackageType)t;
+ (TCDPackageArch)archFromString:(NSString *)s;
+ (NSString *)stringForArch:(TCDPackageArch)a;
+ (NSString *)stringForArchMask:(TCDPackageArch)a;

/* Dotted-version compare that tolerates the "1.8.0_202" style used by some
   legacy packages. Returns >0 if a is newer than b. */
+ (NSInteger)compareVersion:(NSString *)a toVersion:(NSString *)b;

- (BOOL)isSystemLevel;
- (NSString *)localizedSizeString;
- (NSString *)localizedTypeString;

@end
