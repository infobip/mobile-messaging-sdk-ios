//
//  UserSessionMapper.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 23.01.2020.
//

import Foundation

class UserSessionMapper {
    class func requestPayload(newSessions: [UserSessionReportObject]?, finishedSessions: [UserSessionReportObject]?) -> RequestBody {
        var ret = RequestBody()
        if let newSessions = newSessions, !newSessions.isEmpty {
            ret[Consts.UserSessions.sessionStarts] = newSessions.map { DateStaticFormatters.ISO8601SecondsFormatter.string(from: $0.startDate) }
        }
        
        if let finishedSessions = finishedSessions, !finishedSessions.isEmpty {
            let deduplicatedFinishedSessions = distinct(
                source: finishedSessions,
                distinctAttribute: {DateStaticFormatters.ISO8601SecondsFormatter.string(from:$0.startDate)})
            { (l, r) -> UserSessionReportObject in
                return l.endDate.compare(r.endDate) == ComparisonResult.orderedDescending ? l : r
            }
            
            ret[Consts.UserSessions.sessionBounds] = Dictionary(uniqueKeysWithValues: deduplicatedFinishedSessions.map{
                (DateStaticFormatters.ISO8601SecondsFormatter.string(from:$0.startDate),
                 DateStaticFormatters.ISO8601SecondsFormatter.string(from:$0.endDate))
            })
        }
        ret["systemData"] = MobileMessaging.userAgent.systemData.requestPayload
        return ret
    }
}

struct DistinctWrapper <T, E : Hashable>: Hashable {
    var underlyingObject: T
    var distinctAttribute: E
    func hash(into hasher: inout Hasher) {
        hasher.combine(distinctAttribute)
    }
}
/// Returns distinct collection, duplicates conflicts resolved by custom resolution implementation
/// - parameter source: Collectiom that may contain duplicate objects
/// - parameter distinctAttribute: Objects property that is needed to be deduplicated
/// - parameter element: The source collection element
/// - parameter resolution: Block that resolves the conflict between two elements of the source collection. Returns element that must remain in deduplicated resulting collection
/// - parameter l: One of the conflicting source collection element
/// - parameter r: One of the conflicting source collection element
/// - returns: Deduplicated source array
func distinct<S : Sequence, T, E : Hashable>(source: S,
                                             distinctAttribute: (_ element: T) -> E,
                                             resolution: (_ l: T, _ r: T) -> T) -> [T]  where S.Element == T {
    var added = Set<DistinctWrapper<T, E>>()
    for next in source.map({
        return DistinctWrapper(underlyingObject: $0, distinctAttribute: distinctAttribute($0))
    }) {autoreleasepool{
        if let indexOfExisting = added.firstIndex(of: next) {
            let prev = added[indexOfExisting]
            let winner = resolution(prev.underlyingObject, next.underlyingObject)
            added.update(with: DistinctWrapper(underlyingObject: winner, distinctAttribute: distinctAttribute(winner)))
        } else {
            added.insert(next)
        }
    }}
    return Array(added).map( { return $0.underlyingObject } )
}
func == <T, E>(lhs: DistinctWrapper<T, E>, rhs: DistinctWrapper<T, E>) -> Bool {
    return lhs.hashValue == rhs.hashValue
}
