#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\Core\MappingHistoryService.ahk

try {
    history := MappingHistoryService(2)
    MappingHistoryAssert(!history.Commit("same", "same"),
        "An unchanged mapping state created a history entry.")
    history.Commit("one", "two", {Kind: "add", Id: "a"})
    history.Commit("two", "three", {Kind: "edit", Id: "a"})
    history.Commit("three", "four", {Kind: "toggle", Id: "a"})
    MappingHistoryAssert(history.GetUndoCount() == 2
            && history.GetRedoCount() == 0,
        "Mapping history did not enforce its capacity.")

    transitions := []
    MappingHistoryAssert(history.Undo(
        RecordMappingHistoryTransition.Bind(transitions), &entry),
        "Undo did not apply the newest mapping snapshot.")
    MappingHistoryAssert(transitions[1] == "three|four"
            && entry.Action.Kind == "toggle"
            && history.GetUndoCount() == 1
            && history.GetRedoCount() == 1,
        "Undo used the wrong direction or moved the wrong entry.")

    failureRaised := false
    try history.Undo(ThrowMappingHistoryTransition)
    catch
        failureRaised := true
    MappingHistoryAssert(failureRaised && history.GetUndoCount() == 1
            && history.GetRedoCount() == 1,
        "A failed undo moved or lost its history entry.")

    MappingHistoryAssert(history.Redo(
        RecordMappingHistoryTransition.Bind(transitions)),
        "Redo did not apply the forward mapping snapshot.")
    MappingHistoryAssert(transitions[2] == "four|three"
            && history.GetUndoCount() == 2
            && history.GetRedoCount() == 0,
        "Redo used the wrong direction or moved the wrong entry.")

    history.Undo(RecordMappingHistoryTransition.Bind(transitions))
    MappingHistoryAssert(history.Commit("three", "five", {Kind: "edit"})
            && history.GetRedoCount() == 0,
        "A new mapping mutation did not clear the redo branch.")

    reentrantAccepted := true
    history.Undo(ReentrantMappingHistoryTransition.Bind(history,
        &reentrantAccepted))
    MappingHistoryAssert(!reentrantAccepted,
        "Mapping history accepted a reentrant transition.")

    boundedHistory := MappingHistoryService(20, 12)
    boundedHistory.Commit("aaaa", "bbbb")
    boundedHistory.Commit("bbbb", "cccc")
    MappingHistoryAssert(boundedHistory.GetUndoCount() == 1
            && boundedHistory.GetStoredCharacterCount() == 8,
        "Mapping history exceeded its aggregate snapshot budget.")
    boundedHistory.Undo((*) => true)
    MappingHistoryAssert(boundedHistory.GetStoredCharacterCount() == 8,
        "Moving an entry to redo duplicated its snapshot budget.")
    boundedHistory.Commit("cccc", "dd")
    MappingHistoryAssert(boundedHistory.GetRedoCount() == 0
            && boundedHistory.GetStoredCharacterCount() == 6,
        "Clearing a redo branch did not release its snapshot budget.")
    boundedHistory.Clear()
    MappingHistoryAssert(boundedHistory.GetStoredCharacterCount() == 0,
        "Clearing mapping history retained its snapshot budget.")

    FileAppend("PASS mapping history service`n", "*")
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
ExitApp(0)

RecordMappingHistoryTransition(calls, targetState, sourceState) {
    calls.Push(targetState "|" sourceState)
}

ThrowMappingHistoryTransition(*) {
    throw Error("expected mapping history failure")
}

ReentrantMappingHistoryTransition(history, &accepted, *) {
    accepted := history.Undo((*) => true)
}

MappingHistoryAssert(value, message) {
    if !value
        throw Error(message)
}
