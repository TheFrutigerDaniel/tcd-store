//
//  TCDIndexParser.m
//  TCD Store
//

#import "TCDIndexParser.h"

@implementation TCDIndexParser

+ (NSArray *)parseIndexData:(NSData *)data
               baseURLString:(NSString *)baseURLString
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
    NSArray *out = [self parseIndexString:text
                 baseURLString:baseURLString
            sourceIdentifier:sourceIdentifier];
    if (skippedOut) *skippedOut = bad;
    return out;
}

+ (NSArray *)parseIndexString:(NSString *)text
                baseURLString:(NSString *)baseURLString
           sourceIdentifier:(NSString *)sourceIdentifier {
    NSMutableArray *stanzas = [NSMutableArray array];
    if (!text.length) return [NSArray array];

    NSArray *rawLines = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
    NSMutableString *description = [NSMutableString string];
    __block NSString *lastKey = nil;   // reassigned inside flush()

    void (^flush)(void) = ^{
        if (fields.count) {
            TCDPackage *p = [self packageFromFields:fields
                                          description:description
                                     baseURLString:baseURLString
                                    sourceIdentifier:sourceIdentifier];
            if (p) [stanzas addObject:p];
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

    return [self mergeStanzas:stanzas];
}

/* A source may list the same Package more than once with different Versions.
   That is what makes downgrade possible: the older stanzas stay in the index
   so the store can offer them, and the newest one supplies the package's
   current metadata. */
+ (NSArray *)mergeStanzas:(NSArray *)stanzas {
    NSMutableArray *ordered = [NSMutableArray array];
    NSMutableDictionary *heads = [NSMutableDictionary dictionary];
    NSMutableDictionary *entriesByID = [NSMutableDictionary dictionary];

    for (TCDPackage *p in stanzas) {
        NSString *key = p.identifier;
        TCDPackage *head = [heads objectForKey:key];
        if (!head) {
            // the first sighting of a Package is the newest, so it is the one
            // the store shows and the one that owns the version list
            [heads setObject:p forKey:key];
            [entriesByID setObject:[NSMutableArray array] forKey:key];
            [ordered addObject:p];
            head = p;
        }
        NSMutableArray *entries = [entriesByID objectForKey:key];
        [entries addObject:[NSDictionary dictionaryWithObjectsAndKeys:
            p.version,          @"version",
            [NSNumber numberWithUnsignedLongLong:p.sizeBytes], @"sizeBytes",
            p.sha256 ?: @"",    @"sha256",
            p.downloadURLString ?: @"", @"downloadURLString", nil]];

        if ([TCDPackage compareVersion:p.version toVersion:head.version] > 0) {
            // shouldn't happen given the sort below, but stay correct if it does
            head.version = p.version;
            head.downloadURLString = p.downloadURLString;
            head.sha256 = p.sha256;
            head.sizeBytes = p.sizeBytes;
        }
    }

    // availableVersions is an NSArray, so the accumulation stayed local and
    // the finished newest-first list is assigned here in one go. The sort also
    // makes insertion order irrelevant, which is what the old code was reaching
    // for by inserting each entry at index 0.
    for (TCDPackage *head in ordered) {
        [head setAvailableVersions:
            [[entriesByID objectForKey:head.identifier] sortedArrayUsingComparator:
                ^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                    return [TCDPackage compareVersion:[b objectForKey:@"version"]
                                             toVersion:[a objectForKey:@"version"]];
                }]];
    }
    return ordered;
}

+ (TCDPackage *)packageFromFields:(NSDictionary *)f
                      description:(NSString *)description
                    baseURLString:(NSString *)baseURLString
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
    // A Cydia index carries Filename: *relative to the source*, so it has
    // to be resolved against where the index itself came from. Used raw it
    // is not a URL at all, and nothing can fetch it.
    p.downloadURLString  = [self resolveFilename:f[@"Filename"]
                                 againstBase:baseURLString];
    // spelled out rather than folded into one bracket expression: an elvis
    // operator sitting inside brackets right after a subscript trips clang's
    // optional-chaining parse, and two fields with a fallback reads better than
    // the operator did
    NSString *sha = f[@"TCD-SHA256"];
    if (!sha.length) sha = f[@"SHA256"];
    p.sha256             = [sha lowercaseString];
    p.installPrefix      = f[@"TCD-Prefix"];
    p.minimumSystemVersion = f[@"TCD-MinOS"] ?: @"10.7";

    // hoisted to a local first: a subscript written directly in front of ?:
    // while still inside the call's brackets is the shape clang mis-parses,
    // so the fallback is resolved before it goes into the message send
    NSString *typeStr = f[@"TCD-Type"] ?: f[@"Type"];
    p.type = [TCDPackage typeFromString:(typeStr ?: @"app")];

    NSString *archStr = f[@"TCD-Arch"] ?: f[@"Architecture"];
    p.arch = [TCDPackage archFromString:(archStr ?: @"any")];

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
/* Filename: is relative to the source index. A value that is already
   absolute is left alone; with no base to resolve against the raw value is
   better than a wrong guess. */
+ (NSString *)resolveFilename:(NSString *)filename againstBase:(NSString *)base {
    if (!filename.length) return @"";
    NSURL *candidate = [NSURL URLWithString:filename];
    if (candidate.scheme.length) return filename;
    if (!base.length) return filename;
    NSURL *baseURL = [NSURL URLWithString:base];
    if (!baseURL.scheme.length) return filename;
    NSURL *resolved = [NSURL URLWithString:filename relativeToURL:baseURL];
    NSString *absolute = resolved.absoluteURL.absoluteString;
    return absolute.length ? absolute : filename;
}

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
