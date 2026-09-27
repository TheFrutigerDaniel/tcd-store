//
//  TCDResolver.m
//  TCD Store
//

#import "TCDResolver.h"

@implementation TCDInstallPlan

- (id)init {
    self = [super init];
    if (self) {
        _packages            = [NSArray array];
        _primaryIdentifiers  = [NSArray array];
        _blockingConflicts   = [NSArray array];
    }
    return self;
}

- (BOOL)isValid {
    return [self.blockingConflicts count] == 0 && [self.failureReason length] == 0;
}

- (unsigned long long)totalSizeBytes {
    unsigned long long total = 0;
    for (TCDPackage *p in self.packages) total += p.sizeBytes;
    return total;
}

- (BOOL)requiresPrivilege {
    for (TCDPackage *p in self.packages) {
        if ([p isSystemLevel]) return YES;
    }
    return NO;
}

@end

@implementation TCDConflict
- (NSString *)description {
    return [NSString stringWithFormat:@"%@ conflicts with %@",
            self.name, self.conflictingWithName];
}
@end

@implementation TCDResolver {
    NSMutableDictionary *_byIdentifier;   // identifier -> TCDPackage
}

- (id)initWithCatalogue:(NSArray *)catalogue {
    self = [super init];
    if (self) {
        _byIdentifier = [NSMutableDictionary dictionaryWithCapacity:catalogue.count];
        for (TCDPackage *p in catalogue) {
            if (p.identifier.length) _byIdentifier[p.identifier] = p;
        }
    }
    return self;
}

- (TCDPackage *)packageWithIdentifier:(NSString *)identifier {
    return identifier ? _byIdentifier[identifier] : nil;
}

/* ------------------------------------------------------------------ */
/* install planning                                                     */
/* ------------------------------------------------------------------ */

- (TCDInstallPlan *)planForPackage:(TCDPackage *)pkg {
    return [self planForPackages:(pkg ? [NSArray arrayWithObject:pkg] : [NSArray array])
                  withPrimary:(pkg ? [NSArray arrayWithObject:pkg.identifier] : [NSArray array])];
}

- (TCDInstallPlan *)planForPackages:(NSArray *)pkgs {
    NSMutableArray *ids = [NSMutableArray array];
    for (TCDPackage *p in pkgs) if (p.identifier) [ids addObject:p.identifier];
    return [self planForPackages:pkgs withPrimary:ids];
}

- (TCDInstallPlan *)planForPackages:(NSArray *)pkgs withPrimary:(NSArray *)primary {
    TCDInstallPlan *plan = [[TCDInstallPlan alloc] init];
    plan.primaryIdentifiers = primary;

    NSMutableSet *planned = [NSMutableSet set];
    NSMutableSet *missing = [NSMutableSet set];
    NSMutableArray *ordered = [NSMutableArray array];

    // Depth-first so dependencies always land before their dependents.
    [self visit:pkgs into:ordered seen:planned missing:missing];

    plan.packages = ordered;

    for (NSString *identifier in missing) {
        plan.failureReason =
            [NSString stringWithFormat:
                @"%@ requires a package that is not in any source: %@",
                [self nameForIdentifierIn:ordered fallback:identifier], identifier];
        return plan;
    }

    // Conflicts are checked against what is already on the machine.
    NSMutableArray *conflicts = [NSMutableArray array];
    for (TCDPackage *p in ordered) {
        for (NSString *other in p.conflicts) {
            TCDPackage *installed = _byIdentifier[other];
            if (installed.installed && ![planned containsObject:other]) {
                TCDConflict *c = [[TCDConflict alloc] init];
                c.identifier = p.identifier;
                c.name = p.name;
                c.conflictingWithName = installed.name;
                [conflicts addObject:c];
            }
        }
    }
    plan.blockingConflicts = conflicts;
    return plan;
}

- (void)visit:(NSArray *)queue
        into:(NSMutableArray *)ordered
        seen:(NSMutableSet *)seen
     missing:(NSMutableSet *)missing {
    for (TCDPackage *p in queue) {
        if (!p.identifier || [seen containsObject:p.identifier]) continue;
        [seen addObject:p.identifier];
        NSMutableArray *deps = [NSMutableArray array];
        for (NSString *d in p.dependencies) {
            TCDPackage *dp = _byIdentifier[d];
            if (dp) [deps addObject:dp];
            else    [missing addObject:d];
        }
        [self visit:deps into:ordered seen:seen missing:missing];
        [ordered addObject:p];
    }
}

- (NSString *)nameForIdentifierIn:(NSArray *)list fallback:(NSString *)identifier {
    for (TCDPackage *p in list) if ([p.identifier isEqualToString:identifier]) return p.name;
    return identifier;
}

/* ------------------------------------------------------------------ */
/* removal                                                              */
/* ------------------------------------------------------------------ */

- (NSArray *)removalBlockersForPackage:(TCDPackage *)pkg {
    NSMutableArray *blockers = [NSMutableArray array];
    for (TCDPackage *p in _byIdentifier.allValues) {
        if (!p.installed || [p.identifier isEqualToString:pkg.identifier]) continue;
        if ([p.dependencies containsObject:pkg.identifier]) [blockers addObject:p];
    }
    return blockers;
}

- (NSArray *)orphansAfterRemovingPackage:(TCDPackage *)pkg {
    NSMutableSet *going = [NSMutableSet setWithObject:pkg.identifier];
    NSMutableArray *orphans = [NSMutableArray array];
    BOOL changed = YES;

    while (changed) {
        changed = NO;
        for (TCDPackage *x in _byIdentifier.allValues) {
            if (!x.installed || !x.autoInstalled) continue;
            if ([going containsObject:x.identifier]) continue;
            // x may only go if something already in the removal set needs it.
            BOOL needed = NO;
            for (TCDPackage *y in _byIdentifier.allValues) {
                if (![going containsObject:y.identifier]) continue;
                if ([y.dependencies containsObject:x.identifier]) { needed = YES; break; }
            }
            if (needed) {
                [going addObject:x.identifier];
                [orphans addObject:x];
                changed = YES;
            }
        }
    }
    return orphans;
}

@end
