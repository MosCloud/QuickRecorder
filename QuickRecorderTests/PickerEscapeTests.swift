//
//  PickerEscapeTests.swift
//  QuickRecorderTests
//

import Testing
@testable import QuickRecorder

@Suite("What an Esc does in a picker")
struct PickerEscapeTests {
    private func action(ownWindow: Bool = true, bubbleOpen: Bool = false, colourWindowOpen: Bool = false,
                        hasChoice: Bool = true, isRepeat: Bool = false) -> PickerEscape {
        PickerEscape.action(ownWindow: ownWindow, bubbleOpen: bubbleOpen, colourWindowOpen: colourWindowOpen,
                            hasChoice: hasChoice, isRepeat: isRepeat)
    }

    @Test("Esc in another of the app's windows is left alone")
    func otherWindow() {
        #expect(action(ownWindow: false) == .passOn)
        // Even with a choice to clear: the picker must not lose it from the settings window's Esc
        #expect(action(ownWindow: false, hasChoice: true) == .passOn)
    }

    @Test("An open bubble takes the Esc before the choice does")
    func bubbleFirst() {
        #expect(action(bubbleOpen: true) == .passOn)
        #expect(action(bubbleOpen: true, hasChoice: true) == .passOn)
    }

    @Test("The colour window takes it before the bubble and the choice")
    func colourWindowFirst() {
        #expect(action(colourWindowOpen: true) == .passOn)
        #expect(action(bubbleOpen: false, colourWindowOpen: true, hasChoice: true) == .passOn)
    }

    @Test("With something chosen the Esc clears it and leaves the picker open")
    func clearsChoice() {
        #expect(action(hasChoice: true) == .clearChoice)
    }

    @Test("With nothing chosen the Esc closes the picker")
    func closesPicker() {
        #expect(action(hasChoice: false) == .closePicker)
    }

    @Test("A held Esc clears once and then does nothing")
    func heldKey() {
        // The first press is not a repeat: it clears. The repeats that follow are swallowed, so holding the key never
        // reaches the layer that closes the picker
        #expect(action(hasChoice: true, isRepeat: false) == .clearChoice)
        #expect(action(hasChoice: true, isRepeat: true) == .swallowRepeat)
        #expect(action(hasChoice: false, isRepeat: true) == .swallowRepeat)
    }

    @Test("A repeat while a bubble is open still belongs to the bubble")
    func repeatWithBubble() {
        #expect(action(bubbleOpen: true, isRepeat: true) == .passOn)
    }
}
