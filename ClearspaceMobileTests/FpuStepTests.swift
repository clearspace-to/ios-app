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
    // Unlike the web form, typing on the phone is held to the floor too: a
    // super in the field can only move progress forward.

    func testTypingCannotGoBelowLastWeek() {
        let row = step(value: 55, previous: 55)
        XCTAssertEqual(row.typed("40"), 55, "A typed value under last week is pulled up to it")
        XCTAssertEqual(row.typed("0"), 55)
        XCTAssertEqual(row.typed("55"), 55)
    }

    func testTypingAboveLastWeekIsTakenAsIs() {
        let row = step(value: 55, previous: 55)
        // No 5% snapping on a typed value — 63 means 63.
        XCTAssertEqual(row.typed("63"), 63)
        XCTAssertEqual(row.typed("100"), 100)
    }

    func testTypedValuesAreCappedAtOneHundred() {
        let row = step(value: nil, previous: 20)
        XCTAssertEqual(row.typed("120"), 100)
        XCTAssertEqual(row.typed("999999999999999999999"), 100,
                       "A long paste must clamp rather than overflow")
    }

    func testClearingTheFieldMeansNoAnswerRatherThanZero() {
        // Filing null leaves whatever the shared row already had; it is not a
        // way to record a lower number.
        XCTAssertNil(step(value: 55, previous: 55).typed(""))
        XCTAssertNil(step(value: 55, previous: 55).typed("   "))
    }

    func testNonDigitsAreIgnored() {
        let row = step(value: nil, previous: 10)
        XCTAssertEqual(row.typed("6a3"), 63)
        XCTAssertEqual(row.typed("-40"), 40, "A minus sign can't sneak a value below the floor")
    }

    func testTypingIsFlooredAtZeroWithNoHistory() {
        let row = step(value: nil, previous: nil)
        XCTAssertEqual(row.typed("0"), 0)
        XCTAssertEqual(row.typed("35"), 35)
    }

    func testPartialTypingClampsWithoutLosingTheNextKeystroke() {
        // What the row relies on: value is clamped every keystroke, but the raw
        // text it holds is what the next keystroke appends to. Floor 55, the
        // super types 7 then 0 to reach 70.
        let row = step(value: 55, previous: 55)
        XCTAssertEqual(row.typed("7"), 55, "Mid-typing the value is held at the floor")
        XCTAssertEqual(row.typed("70"), 70, "The completed number is accepted")
    }
}
