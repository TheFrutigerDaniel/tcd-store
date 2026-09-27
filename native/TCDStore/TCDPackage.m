//
//  TCDPackage.m
//  TCD Store
//

#import "TCDPackage.h"

@implementation TCDPackage

- (id)init {
    self = [super init];
    if (self) {
        _type = TCDPackageTypeApp;
        _arch = TCDPackageArchAny;
        _dependencies = [[NSArray alloc] init];
        _conflicts    = [[NSArray alloc] init];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    TCDPackage *p = [[TCDPackage allocWithZone:zone] init];
    p.identifier        = self.identifier;
    p.sourceIdentifier  = self.sourceIdentifier;
    p.name              = self.name;
    p.version           = self.version;
    p.packageSummary    = self.packageSummary;
    p.packageDescription = self.packageDescription;
    p.developer         = self.developer;
    p.section           = self.section;
    p.changelog         = self.changelog;
    p.iconURLString     = self.iconURLString;
    p.downloadURLString = self.downloadURLString;
    p.sha256            = self.sha256;
    p.installPrefix     = self.installPrefix;
    p.type              = self.type;
    p.arch              = self.arch;
    p.sizeBytes         = self.sizeBytes;
    p.ratingCount       = self.ratingCount;
    p.ratingAverage     = self.ratingAverage;
    p.minimumSystemVersion = self.minimumSystemVersion;
    p.dependencies      = self.dependencies;
    p.conflicts         = self.conflicts;
    p.installed         = self.installed;
    p.installedVersion  = self.installedVersion;
    p.autoInstalled     = self.autoInstalled;
    p.receiptID         = self.receiptID;
    return p;
}

- (BOOL)hasUpdate {
    if (!self.installed || self.installedVersion.length == 0) return NO;
    return [TCDPackage compareVersion:self.version toVersion:self.installedVersion] > 0;
}

+ (TCDPackageType)typeFromString:(NSString *)s {
    if ([s caseInsensitiveCompare:@"app"]      == NSOrderedSame) return TCDPackageTypeApp;
    if ([s caseInsensitiveCompare:@"pkg"]      == NSOrderedSame) return TCDPackageTypePkg;
    if ([s caseInsensitiveCompare:@"kext"]     == NSOrderedSame) return TCDPackageTypeKext;
    if ([s caseInsensitiveCompare:@"prefpane"] == NSOrderedSame) return TCDPackageTypePrefPane;
    return TCDPackageTypeApp;
}

+ (NSString *)stringForType:(TCDPackageType)t {
    switch (t) {
        case TCDPackageTypeApp:      return @"app";
        case TCDPackageTypePkg:      return @"pkg";
        case TCDPackageTypeKext:     return @"kext";
        case TCDPackageTypePrefPane: return @"prefpane";
    }
    return @"app";
}

+ (TCDPackageArch)archFromString:(NSString *)s {
    TCDPackageArch a = TCDPackageArchAny;
    if ([s rangeOfString:@"i386"].location != NSNotFound)   a |= TCDPackageArchI386;
    if ([s rangeOfString:@"x86_64"].location != NSNotFound) a |= TCDPackageArchX86_64;
    return a;
}

+ (NSString *)stringForArch:(TCDPackageArch)a {
    if (a == TCDPackageArchAny) return @"any";
    NSMutableString *m = [NSMutableString string];
    if (a & TCDPackageArchI386)   [m appendString:@"i386 "];
    if (a & TCDPackageArchX86_64) [m appendString:@"x86_64 "];
    return [m stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

+ (NSString *)stringForArchMask:(TCDPackageArch)a { return [self stringForArch:a]; }

- (BOOL)isSystemLevel {
    return self.type == TCDPackageTypePkg || self.type == TCDPackageTypeKext;
}

- (NSString *)localizedTypeString {
    switch (self.type) {
        case TCDPackageTypeApp:      return @"Application";
        case TCDPackageTypePkg:      return @"System Package";
        case TCDPackageTypeKext:     return @"Kernel Extension";
        case TCDPackageTypePrefPane: return @"Preference Pane";
    }
    return @"Package";
}

- (NSString *)localizedSizeString {
    unsigned long long n = self.sizeBytes;
    if (n >= 1048576ULL) return [NSString stringWithFormat:@"%.1f MB", n / 1048576.0];
    if (n >= 1024ULL)    return [NSString stringWithFormat:@"%llu KB", n / 1024ULL];
    return [NSString stringWithFormat:@"%llu bytes", n];
}

/* Compares dotted/numeric versions, tolerating the "1.8.0_202" style that
   legacy Java packages use. Returns >0 if a is newer than b. */
+ (NSInteger)compareVersion:(NSString *)a toVersion:(NSString *)b {
    NSArray *pa = [a componentsSeparatedByCharactersInSet:
                   [NSCharacterSet characterSetWithCharactersInString:@"._-"]];
    NSArray *pb = [b componentsSeparatedByCharactersInSet:
                   [NSCharacterSet characterSetWithCharactersInString:@"._-"]];
    NSUInteger n = MAX(pa.count, pb.count);
    for (NSUInteger i = 0; i < n; i++) {
        NSString *x = i < pa.count ? pa[i] : @"0";
        NSString *y = i < pb.count ? pb[i] : @"0";
        NSInteger ix = [x integerValue], iy = [y integerValue];
        if (ix != iy) return ix > iy ? 1 : -1;
        if (ix == 0 && ![x isEqualToString:y]) {         // non-numeric remainder
            NSComparisonResult r = [x compare:y];
            if (r != NSOrderedSame) return r == NSOrderedDescending ? 1 : -1;
        }
    }
    return 0;
}

@end
