import XCTest
@testable import ClearspaceMobile

/// The ±5% step floor on the FPU entry form.
///
/// The rule shipped on the web first ("progress doesn't run backwards, but a
/// step down lands ON last week's number"); these lock the iOS copy to the same
/// behaviour, including the off-grid case the first web version got wrong.
final class FpuStepTests: XCTestCase {

    private func step(value: Int?, previous: Int?) -> FpuStep {
        FpuStep(previous: previous, value: value)
    }

    func testStepUpSnapsToTheFivePercentGrid() {
        XCTAssertEqual(step(value: 80, previous: 75).stepped(by: 5), 85)
        XCTAssertEqual(step(value: 82, previous: 75).stepped(by: 5), 85,
                       "An off-grid value should land on the grid, not at 87")
    }

    func testStepDownStopsOnLastWeeksNumber() {
        XCTAssertEqual(step(value: 90, previous: 80).stepped(by: -5), 85)
        XCTAssertEqual(step(value: 85, previous: 80).stepped(by: -5), 80)
        XCTAssertEqual(step(value: 82, previous: 80).stepped(by: -5), 80,
                       "82 is above last week, so it must be able to come back to 80")
    }

    func testMinusIsDisabledOnlyOnceThereIsNowhereLeftToGo() {
        XCTAssertFalse(step(value: 82, previous: 80).atFloor,
                       "Above last week — 80 is still a legal target, so the button must stay live")
        XCTAssertTrue(step(value: 80, previous: 80).atFloor)
        XCTAssertTrue(step(value: 75, previous: 80).atFloor,
                      "Already under the floor (typed correction): no step down to offer")
    }

    func testAnUnsetDivisionStepsFromLastWeeksNumber() {
        XCTAssertEqual(step(value: nil, previous: 60).stepped(by: 5), 65)
        XCTAssertEqual(step(value: nil, previous: 60).stepped(by: -5), 60,
                       "Stepping down from untouched holds at last week rather than dropping below")
        XCTAssertTrue(step(value: nil, previous: 60).atFloor)
    }

    func testADivisionWithNoHistoryFloorsAtZero() {
        XCTAssertEqual(step(value: 5, previous: nil).stepped(by: -5), 0)
        XCTAssertTrue(step(value: 0, previous: nil).atFloor)
        XCTAssertTrue(step(value: nil, previous: nil).atFloor,
                      "Nothing entered and no history: the minus would do nothing")
    }

    func testStepsStayInsideZeroToOneHundred() {
        XCTAssertEqual(step(value: 100, previous: 90).stepped(by: 5), 100)
        XCTAssertEqual(step(value: 98, previous: 90).stepped(by: 5), 100)
        XCTAssertEqual(step(value: 100, previous: 100).stepped(by: -5), 100,
                       "A division finished last week can't be walked back by the stepper")
    }

    func testTheFloorIsLastWeekOrZero() {
        XCTAssertEqual(step(value: nil, previous: 45).floor, 45)
        XCTAssertEqual(step(value: nil, previous: nil).floor, 0)
    }

    // MARK: - Typed values
    //
    // Unlike the web form, typing on the phone can't go under last week either.
    // It is refused outright rather than quietly corrected, so the super is
    // told why their number didn't stick.

    func testTypingBelowLastWeekIsRefused() {
        let row = step(value: 55, previous: 55)
        XCTAssertEqual(row.typed("40"), .refused(40))
        XCTAssertEqual(row.typed("0"), .refused(0))
    }

    func testTypingAtOrAboveLastWeekIsAccepted() {
        let row = step(value: 55, previous: 55)
        XCTAssertEqual(row.typed("55"), .accepted(55))
        // No 5% snapping on a typed value — 63 means 63.
        XCTAssertEqual(row.typed("63"), .accepted(63))
        XCTAssertEqual(row.typed("100"), .accepted(100))
    }

    func testTypedValuesAreCappedAtOneHundred() {
        let row = step(value: nil, previous: 20)
        XCTAssertEqual(row.typed("120"), .accepted(100))
        XCTAssertEqual(row.typed("999999999999999999999"), .accepted(100),
                       "A long paste must cap rather than overflow")
    }

    func testClearingTheFieldMeansNoAnswerRatherThanZero() {
        // Filing null leaves whatever the shared row already had; it is not a
        // way to record a lower number, so it isn't refused.
        XCTAssertEqual(step(value: 55, previous: 55).typed(""), .cleared)
        XCTAssertEqual(step(value: 55, previous: 55).typed("   "), .cleared)
    }

    func testNonDigitsAreIgnoredRatherThanChangingTheNumber() {
        let row = step(value: nil, previous: 10)
        XCTAssertEqual(row.typed("6a3"), .accepted(63))
        XCTAssertEqual(row.typed("-40"), .accepted(40),
                       "A minus sign is dropped, not read as a negative")
    }

    func testWithNoHistoryAnythingFromZeroUpIsAccepted() {
        let row = step(value: nil, previous: nil)
        XCTAssertEqual(row.typed("0"), .accepted(0))
        XCTAssertEqual(row.typed("35"), .accepted(35))
    }

    func testAPartialNumberIsJudgedOnlyWhenCommitted() {
        // The field is read on blur, not per keystroke, so "7" is only ever
        // evaluated if the super actually leaves it there.
        let row = step(value: 55, previous: 55)
        XCTAssertEqual(row.typed("7"), .refused(7))
        XCTAssertEqual(row.typed("70"), .accepted(70))
    }
}
