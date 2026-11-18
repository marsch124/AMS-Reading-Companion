import Foundation
import ReadingCore

// Version 0.8: what the screens ask the shelf to do.
extension ReadingModel {
    /// Puts books away (off every shelf; the search still finds them), or takes them out again.
    func setPutAway(_ away: Bool, of ids: [String]) { change { $0.setPutAway(away, of: ids) } }

    /// Makes `other` part of `id` (copies, notes and tags move over). False when nothing was joined.
    @discardableResult
    func join(_ other: String, into id: String) -> Bool {
        var done = false
        change { done = $0.join(other, into: id) }
        return done
    }

    func setStatus(_ status: ReadStatus, ofAll ids: [String]) { change { $0.setStatus(status, ofAll: ids) } }
    func addTag(_ tag: String, toAll ids: [String]) { change { $0.addTag(tag, toAll: ids) } }
    func addUpNext(all ids: [String]) { change { $0.addUpNext(all: ids) } }

    /// The parts of the main screen that are switched off.
    func setHiddenParts(_ parts: [MainPart]) { change { $0.setHiddenParts(parts) } }

    /// Ticks a To do note off, or opens it again.
    func setDone(_ done: Bool, note id: String) { change { $0.setDone(done, note: id) } }
}
