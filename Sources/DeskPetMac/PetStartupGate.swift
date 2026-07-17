struct PetStartupGate {
    private var hasStarted = false

    mutating func claim() -> Bool {
        guard !hasStarted else { return false }
        hasStarted = true
        return true
    }
}
