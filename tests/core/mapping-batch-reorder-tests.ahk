#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\Core\BoundedFileReader.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\ScriptRuleSpec.ahk
#Include ..\..\src\Core\RuleCompiler.ahk
#Include ..\..\src\Core\ScriptRuleCompiler.ahk
#Include ..\..\src\Core\MappingCodeRepository.ahk

try {
    repository := BatchReorderRepository(["a", "b", "c", "d", "e"])
    BatchReorderAssert(repository.MoveManyTo(["d", "b"], 6),
        "A noncontiguous selection was not moved to the end.")
    BatchReorderAssertOrder(repository, ["a", "c", "e", "b", "d"],
        "Batch reordering did not preserve source order.")

    BatchReorderAssert(repository.MoveManyTo(["d", "b"], 1),
        "The selected group was not moved to the beginning.")
    BatchReorderAssertOrder(repository, ["b", "d", "a", "c", "e"],
        "Moving a group to the beginning reversed its order.")
    rewriteCount := repository.RewriteCount
    BatchReorderAssert(!repository.MoveManyTo(["b", "d"], 3)
            && repository.RewriteCount == rewriteCount,
        "A no-op group move rewrote the repository.")

    middleRepository := BatchReorderRepository(["a", "b", "c", "d", "e"])
    BatchReorderAssert(middleRepository.MoveManyTo(["b", "d"], 4),
        "A sparse selection was not moved to the requested insertion slot.")
    BatchReorderAssertOrder(middleRepository, ["a", "c", "b", "d", "e"],
        "The original insertion slot was converted incorrectly.")
    BatchReorderAssertThrows(() => middleRepository.MoveManyTo(
        ["b", "missing"], 1),
        "A missing selected rule was silently ignored.")
    FileAppend("PASS mapping batch reorder`n", "*")
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
ExitApp(0)

BatchReorderAssert(value, message) {
    if !value
        throw Error(message)
}

BatchReorderAssertOrder(repository, expectedIds, message) {
    actualIds := []
    for mapping in repository.TestMappings
        actualIds.Push(mapping.Id)
    if actualIds.Length != expectedIds.Length
        throw Error(message)
    for index, expectedId in expectedIds {
        if actualIds[index] != expectedId
            throw Error(message " Expected " expectedId " at " index
                ", got " actualIds[index] ".")
    }
}

BatchReorderAssertThrows(callback, message) {
    try callback.Call()
    catch
        return true
    throw Error(message)
}

class BatchReorderRepository extends MappingCodeRepository {
    __New(mappingIds) {
        this.TestMappings := []
        this.RewriteCount := 0
        for mappingId in mappingIds
            this.TestMappings.Push({Id: mappingId})
    }

    ReadSnapshot() => {Mappings: this.TestMappings.Clone()}

    Rewrite(mappings, snapshot?, mappingsValidated := false) {
        this.RewriteCount++
        this.TestMappings := mappings.Clone()
        return true
    }
}
