//
//  TCDIndexParser.m
//  TCD Store
//

#import "TCDIndexParser.h"

@implementation TCDIndexParser

+ (NSArray *)parseIndexData:(NSData *)data
          sourceIdentifier:(NSString *)sourceIdentifier
               skippedOut:(NSArray **)skippedOut {
    if (![data length]) {
        if (skippedOut) *skippedOut = [NSArray array];
        return [NSArray array];
    }
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!text) {
        text = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    }
    NSArray *bad = nil;
    NSArray *out = [self parseIndexString:text sourceIdentifier:sourceIdentifier];
    if (skippedOut) *skippedOut = bad;
    return out;
}

+ (NSArray *)parseIndexString:(NSString *)text
           sourceIdentifier:(NSString *)sourceIdentifier {
    NSMutableArray *packages = [NSMutableArray array];
    if (!text.length) return packages;

    NSArray *rawLines = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
    NSMutableString *description = [NSMutableString string];
    NSString *lastKey = nil;

    void (^flush)(void) = ^{
        if (fields.count) {
            TCDPackage *p = [self packageFromFields:fields
                                          description:description
                                     sourceIdentifier:sourceIdentifier];
            if (p) [packages addObject:p];
        }
        [fields removeAllObjects];
        [description setString:@""];
        lastKey = nil;
    };

    NSUInteger i = 0, n = rawLines.count;
    while (i < n) {
        NSString *line = [rawLines[i] stringByTrimmingCharactersInSet:
                          [NSCharacterSet newlineCharacterSet]];
        i++;

        if ([line length] == 0) {                    // stanza separator
            flush();
            continue;
        }
        if ([line hasPrefix:@"#"]) continue;          // comment

        if ([line hasPrefix:@" "]) {                  // continuation
            NSString *cont = [line substringFromIndex:1];
            if ([lastKey isEqualToString:@"Description"]) {
                if ([description length]) [description appendString:@"\n"];
                [description appendString:cont];
            } else if (lastKey && fields[lastKey]) {
                // Fold into a comma-separated list, the Debian convention.
                fields[lastKey] = [NSString stringWithFormat:@"%@,%@", fields[lastKey], cont];
            }
            continue;
        }

        NSRange colon = [line rangeOfString:@":"];
        if (colon.location == NSNotFound || colon.location == 0) continue;
        NSString *key   = [[line substringToIndex:colon.location]
                           stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceCharacterSet]];
        NSString *value = [[line substringFromIndex:colon.location + 1]
                           stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceCharacterSet]];
        fields[key] = value;
        lastKey = key;
    }
    flush();   // trailing stanza with no blank line after it

    return packages;
}

+ (TCDPackage *)packageFromFields:(NSDictionary *)f
                      description:(NSString *)description
                 sourceIdentifier:(NSString *)sourceIdentifier {
    NSString *name = f[@"Package"];
    if (!name.length) return nil;                     // unusable stanza
    NSString *version = f[@"Version"];
    if (!version.length) version = @"0";

    TCDPackage *p = [[TCDPackage alloc] init];
    p.identifier         = name;
    p.sourceIdentifier   = sourceIdentifier;
    p.name               = f[@"TCD-Name"] ?: name;
    p.version            = version;
    p.developer          = f[@"TCD-Developer"] ?: @"Unknown";
    p.section            = f[@"TCD-Section"] ?: @"Other";
    p.packageSummary     = f[@"TCD-Summary"] ?: f[@"Description"] ?: @"";
    p.packageDescription = description.length ? description : p.packageSummary;
    p.changelog          = f[@"TCD-Changelog"];
    p.iconURLString      = f[@"TCD-Icon"];
    p.downloadURLString  = f[@"Filename"];
    p.sha256             = [[f[@"TCD-SHA256"] ?: f[@"SHA256"]] lowercaseString];
    p.installPrefix      = f[@"TCD-Prefix"];
    p.minimumSystemVersion = f[@"TCD-MinOS"] ?: @"10.7";

    p.type = [TCDPackage typeFromString:(f[@"TCD-Type"] ?: f[@"Type"] ?: @"app")];
    p.arch = [TCDPackage archFromString:(f[@"TCD-Arch"] ?: f[@"Architecture"] ?: @"any")];

    // Debian's Installed-Size is in kibibytes.
    NSString *isize = f[@"Installed-Size"];
    if (isize.length) p.sizeBytes = (unsigned long long)[isize longLongValue] * 1024ULL;
    if (p.sizeBytes == 0) {
        NSString *bs = f[@"TCD-Size"];
        if (bs.length) p.sizeBytes = (unsigned long long)[bs longLongValue];
    }

    p.dependencies = [self splitList:f[@"Depends"]];
    p.conflicts    = [self splitList:f[@"Conflicts"]];

    if (f[@"TCD-Rating-Count"]) p.ratingCount = [f[@"TCD-Rating-Count"] integerValue];
    if (f[@"TCD-Rating-Average"]) p.ratingAverage = [f[@"TCD-Rating-Average"] doubleValue];

    // A .pkg with no explicit prefix is a system-level install by definition.
    if (p.type == TCDPackageTypePkg && !p.installPrefix.length) {
        p.installPrefix = @"/";
    }
    return p;
}

/* "a, b (>= 1.0), c" -> ["a", "b", "c"]
   Version constraints are parsed away here on purpose: the prototype's
   resolver treats a dependency as satisfied by any version of the named
   package, and tightening that is a resolver change, not a parser change. */
+ (NSArray *)splitList:(NSString *)s {
    if (!s.length) return [NSArray array];
    NSMutableArray *out = [NSMutableArray array];
    NSArray *parts = [s componentsSeparatedByString:@","];
    for (NSString *part in parts) {
        NSString *name = [[part stringByTrimmingCharactersInSet:
                           [NSCharacterSet whitespaceCharacterSet]] copy];
        NSRange paren = [name rangeOfString:@"("];
        if (paren.location != NSNotFound) name = [name substringToIndex:paren.location];
        paren = [name rangeOfString:@"["];
        if (paren.location != NSNotFound) name = [name substringToIndex:paren.location];
        name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (name.length) [out addObject:name];
    }
    return out;
}

@end
