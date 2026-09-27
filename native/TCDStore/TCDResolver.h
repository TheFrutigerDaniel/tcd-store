//
//  TCDResolver.h
//  TCD Store
//
//  Turns "the user pressed Install on Mesa3D" into an ordered list of things
//  to fetch, in dependency order, and tells you when you cannot proceed.
//
//  The two rules that are easy to get wrong, and which the prototype's test
//  suite pinned down:
//
//   1. A plan is only valid if no member conflicts with an already-installed
//      package. Conflicts are checked against the *installed* set, not the
//      plan, so installing A then B in one go is fine but installing B while
//      A is installed is not.
//
//   2. Autoremove is scoped to the dependency closure of what you are
//      removing. "This package has no dependents" is NOT sufficient: an
//      installed application's dependency has no dependents either, and
//      taking it would break the application. Only packages that something
//      in the removal set depends on may go, and only if they were
//      auto-installed in the first place.
//

#import <Foundation/Foundation.h>
#import "TCDPackage.h"

@interface TCDInstallPlan : NSObject
@property (nonatomic, copy) NSArray *packages;          // TCDPackage, dependency order
@property (nonatomic, copy) NSArray *primaryIdentifiers;// what the user actually asked for
@property (nonatomic, copy) NSArray *blockingConflicts;  // TCDConflict records
@property (nonatomic, copy) NSString *failureReason;

/* identifier -> version, for the primary packages only. Dependencies always
   install at whatever version the source currently offers. */
@property (nonatomic, copy) NSDictionary *versionOverrides;
@property (nonatomic, copy) NSString *primaryVersion;
@property (nonatomic, assign) TCDVersionRelation primaryRelation;
- (BOOL)isValid;
- (unsigned long long)totalSizeBytes;
- (BOOL)requiresPrivilege;
@end

@interface TCDConflict : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *conflictingWithName;
@end

@interface TCDResolver : NSObject

- (id)initWithCatalogue:(NSArray *)catalogue;   // every known TCDPackage

/* Resolves the plan for installing or updating one package. */
- (TCDInstallPlan *)planForPackage:(TCDPackage *)pkg;

/* Resolves the plan for one *specific* version of a package. Passing nil is
   the same as -planForPackage:. The plan records the target so the installer
   fetches that stanza's payload rather than the newest one. */
- (TCDInstallPlan *)planForPackage:(TCDPackage *)pkg atVersion:(NSString *)version;

/* Resolves the plan for a batch (Update All). */
- (TCDInstallPlan *)planForPackages:(NSArray *)pkgs;

/* Packages that would become orphaned by removing `pkg`, deepest first.
   Returns nil-equivalent (empty array) if any installed package still
   depends on it, because then the removal is not allowed at all. */
- (NSArray *)removalBlockersForPackage:(TCDPackage *)pkg;
- (NSArray *)orphansAfterRemovingPackage:(TCDPackage *)pkg;

- (TCDPackage *)packageWithIdentifier:(NSString *)identifier;

@end
