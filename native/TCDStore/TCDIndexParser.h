//
//  TCDIndexParser.h
//  TCD Store
//
//  Parses a source index. The format is deliberately the Debian control
//  stanza format that Cydia uses, because it is trivial to generate, trivial
//  to diff, and a maintainer can hand-write one if they have to:
//
//      Package: fakesmc
//      Version: 1.3.1
//      Architecture: any
//      Installed-Size: 228
//      Depends: openscpx
//      Conflicts: smcsuperio
//      TCD-Type: kext
//      TCD-Section: System
//      TCD-Developer: Slice
//      TCD-Prefix: /System/Library/Extensions/FakeSMC.kext
//      TCD-SHA256: 9f2c...
//      TCD-Icon: icons/fakesmc.png
//      TCD-Arch: i386 x86_64
//      TCD-MinOS: 10.7
//      Description: Emulates the SMC so sensors work
//       Long descriptions are continuation lines, indented by one
//       space. Blank lines separate stanzas.
//

#import <Foundation/Foundation.h>
#import "TCDPackage.h"

@interface TCDIndexParser : NSObject

/* Parses a decompressed index. Stanzas that cannot be understood are skipped
   rather than aborting the whole fetch — one broken entry in a third-party
   index must not cost the user every other package in it. */
/* `baseURLString` is where the index was fetched from. Filename: is relative
   to the source index, so it is resolved against this: a Cydia index says
   "demo/foo.zip" and the source at http://example.com/Packages turns that
   into http://example.com/demo/foo.zip. Passing nil leaves Filename: as it
   was written, which is almost never a usable URL. */
+ (NSArray *)parseIndexData:(NSData *)data
               baseURLString:(NSString *)baseURLString
          sourceIdentifier:(NSString *)sourceIdentifier
                   skippedOut:(NSArray **)skippedOut;

+ (NSArray *)parseIndexString:(NSString *)text
                baseURLString:(NSString *)baseURLString
           sourceIdentifier:(NSString *)sourceIdentifier;

@end
