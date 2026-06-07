//=====================
// Advanced Beams - MuseScore Studio 4.x
// v2.5.1-scroll
//
// Section A — Beam Height:
//   Delta: signed direct offset adjust via ▲▼; up=true receives the inverse sign of up=false.
//   Absolute: first sets userModified=true for all target beams, then tries to
//             zero beamPos=(0,0), then writes the user absolute value into
//             offset.y, so old beamPos values do not add up. Custom defaults
//             for up=true/up=false are saved with FileIO.
//   Force horizontal: first sets userModified=true for all target beams, then beamNoSlope=true.
//   Restore slope: beamNoSlope = false.
//   Factory Reset: userModified=false, beamPos/offset/beamNoSlope reset only.
//   Reset Height: restores beamPos/offset/userModified/beamNoSlope to initial state.
//
// Section B — Grow Beams:
//   Adjusts growLeft / growRight independently or together.
//   Reset Grow: restores growLeft/growRight to state before first apply.
//   Factory Reset Grow: growLeft/growRight = 1.0, MuseScore software default.
//   Joint beams: growLeft/growRight = 0.0.
//
// Section C — Select Beams:
//   Filters the current range/selection to beams with up=true or up=false.
//
// Section D — Isolated Stems:
//   Adjusts isolated unbeamed stems by a relative decimal delta using ▲/▼.
//
// Section E — Restore AdvancedBeams:
//   Saves/restores beam state after operations that reset beams, e.g. time signature changes.
//   Restores offset, beamPos, growLeft/growRight, beamNoSlope and userModified.
//
// v2.4 fix:
//   Treats selection.endStaff as an exclusive upper bound, preventing
//   range operations from leaking into the staff immediately below.
//
// Reset All (footer): restores all properties from sections A and B.
//=====================

import QtQuick 2.0
import MuseScore 3.0
import FileIO 3.0

MuseScore {
    id: root
    menuPath:      "Plugins.Advanced Beams"
    description:   "Adjusts Beam Height and Grow Beams for the current selection, with per-session reset."
    version:       "2.5.1-scroll"
    requiresScore: true
    pluginType:    "dialog"
    width:         520
    height:        650

    property string heightDeltaText: "0.05"
    property string absUpText:       "-4.0"
    property string absDownText:     "4.0"
    property string growDeltaText:   "0.05"
    property string stemFactorText:   "0.05"
    property bool   includeGraceNotes: false
    property string statusMsg:       "Select a range and use sections A, B, C, D and E."
    property int    sampleLimit:     4
    property real   growDefaultLeft:  1.0
    property real   growDefaultRight: 1.0
    property real   growJointValue:   0.0
    property var    savedStates:     []
    property var    snapshotStates:  []
    property string snapshotStamp:   ""
    property string snapshotFilePath: ""
    property string fileIoLastError: ""
    property bool   pendingSelectUp: true

    FileIO {
        id: absDefaultsFile
        source: ""
        onError: { root.fileIoLastError = msg }
    }

    FileIO {
        id: snapshotFile
        source: ""
        onError: { root.fileIoLastError = msg }
    }

    Timer {
        id: selectCommitTimer
        interval: 35
        repeat: false
        onTriggered: performSelectBeamsByUp(root.pendingSelectUp)
    }

    Component.onCompleted: {
        if (mscoreMajorVersion >= 4) {
            title        = "Advanced Beams"
            categoryCode = "notes-rests"
        }
        loadAbsoluteDefaults()
    }

    onRun: {
        loadAbsoluteDefaults()
        statusMsg = "Plugin loaded. Select a range and use sections A, B, C, D and E."
    }

    // ═══════════════════════════════════════════════════════════════════════
    // UI
    // ═══════════════════════════════════════════════════════════════════════

    Flickable {
        id: mainFlick
        anchors.fill: parent
        contentWidth: mainPanel.width
        contentHeight: mainPanel.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: true

        Rectangle {
            id: mainPanel
            x: 0; y: 0; width: root.width; height: 840
            color: "#f5f5f5"
            border.color: "#999999"; border.width: 1

            // ── Title ───────────────────────────────────────────────────────
            Text {
                x: 12; y: 10; width: 496
                text: "Advanced Beams — v2.5.1-scroll"
                font.pointSize: 11; font.bold: true; color: "black"
            }

            // ── Status ──────────────────────────────────────────────────────
            Rectangle {
                x: 12; y: 30; width: 496; height: 38
                color: "#ebebeb"; border.color: "#cccccc"; radius: 2
                Text {
                    x: 6; y: 4; width: 484; height: 30
                    text: root.statusMsg
                    wrapMode: Text.WordWrap
                    font.pointSize: 7.5; color: "#222222"; clip: true
                }
            }

            // ════════════════════════════════════════════════════════════════
            // SECTION A — BEAM HEIGHT
            // ════════════════════════════════════════════════════════════════

            Text {
                x: 12; y: 78
                text: "A — Beam Height"
                font.pointSize: 9; font.bold: true; color: "#333333"
            }
            Rectangle { x: 12; y: 92; width: 496; height: 1; color: "#aaaaaa" }

            // ── A1: Delta ───────────────────────────────────────────────────
            Text { x: 12; y: 100; text: "Delta:"; font.pointSize: 8; font.bold: true; color: "#333333" }
            Rectangle {
                x: 52; y: 96; width: 62; height: 24
                color: "white"; border.color: "#777777"; radius: 3
                TextInput {
                    anchors.fill: parent; anchors.margins: 5
                    text: root.heightDeltaText
                    color: "black"; font.pointSize: 9
                    selectByMouse: true
                    validator: DoubleValidator { bottom: 0.001; top: 19.0; decimals: 4; notation: DoubleValidator.StandardNotation }
                    onTextChanged: root.heightDeltaText = text
                }
            }
            Rectangle {
                x: 120; y: 96; width: 26; height: 24
                color: "#d0e8ff"; border.color: "#6699cc"; radius: 3
                Text { anchors.centerIn: parent; text: "▲"; font.pointSize: 10; color: "#003366" }
                MouseArea { anchors.fill: parent; onClicked: runHeightDelta(parseHeightDelta()) }
            }
            Rectangle {
                x: 150; y: 96; width: 26; height: 24
                color: "#d0e8ff"; border.color: "#6699cc"; radius: 3
                Text { anchors.centerIn: parent; text: "▼"; font.pointSize: 10; color: "#003366" }
                MouseArea { anchors.fill: parent; onClicked: runHeightDelta(-parseHeightDelta()) }
            }
            Text { x: 182; y: 100; width: 76; text: "All beams"; font.pointSize: 7.5; color: "#555555" }
            Rectangle {
                x: 258; y: 96; width: 50; height: 24
                color: "#e0f0ff"; border.color: "#6699cc"; radius: 3
                Text { anchors.centerIn: parent; text: "up ▲"; font.pointSize: 7.2; color: "#003366" }
                MouseArea { anchors.fill: parent; onClicked: runHeightDeltaFiltered(parseHeightDelta(), true) }
            }
            Rectangle {
                x: 312; y: 96; width: 50; height: 24
                color: "#e0f0ff"; border.color: "#6699cc"; radius: 3
                Text { anchors.centerIn: parent; text: "up ▼"; font.pointSize: 7.2; color: "#003366" }
                MouseArea { anchors.fill: parent; onClicked: runHeightDeltaFiltered(-parseHeightDelta(), true) }
            }
            Rectangle {
                x: 366; y: 96; width: 62; height: 24
                color: "#e0f0ff"; border.color: "#6699cc"; radius: 3
                Text { anchors.centerIn: parent; text: "down ▲"; font.pointSize: 7.0; color: "#003366" }
                MouseArea { anchors.fill: parent; onClicked: runHeightDeltaFiltered(parseHeightDelta(), false) }
            }
            Rectangle {
                x: 432; y: 96; width: 62; height: 24
                color: "#e0f0ff"; border.color: "#6699cc"; radius: 3
                Text { anchors.centerIn: parent; text: "down ▼"; font.pointSize: 7.0; color: "#003366" }
                MouseArea { anchors.fill: parent; onClicked: runHeightDeltaFiltered(-parseHeightDelta(), false) }
            }

            // ── A2: Absolute Position ───────────────────────────────────────
            Text { x: 12; y: 130; text: "Absolute:"; font.pointSize: 8; font.bold: true; color: "#333333" }

            // Up beams (up=true, stems up, beam above)
            Text { x: 12; y: 150; text: "Up beams:"; font.pointSize: 7.5; color: "#444444" }
            Rectangle {
                x: 72; y: 146; width: 58; height: 24
                color: "white"; border.color: "#777777"; radius: 3
                TextInput {
                    anchors.fill: parent; anchors.margins: 5
                    text: root.absUpText
                    color: "black"; font.pointSize: 9
                    selectByMouse: true
                    validator: DoubleValidator { bottom: -99.0; top: 99.0; decimals: 4; notation: DoubleValidator.StandardNotation }
                    onTextChanged: root.absUpText = text
                }
            }
            Rectangle {
                x: 136; y: 146; width: 52; height: 24
                color: "#d0e8ff"; border.color: "#6699cc"; radius: 3
                Text { anchors.centerIn: parent; text: "Apply ↑"; font.pointSize: 7.5; font.bold: true; color: "#003366" }
                MouseArea { anchors.fill: parent; onClicked: applyAbsolute(true) }
            }
            Text { x: 196; y: 150; width: 158; text: "beamPos→0; offset.y"; font.pointSize: 7; color: "#666666" }

            // Down beams (up=false, stems down, beam below)
            Text { x: 12; y: 178; text: "Down beams:"; font.pointSize: 7.5; color: "#444444" }
            Rectangle {
                x: 72; y: 174; width: 58; height: 24
                color: "white"; border.color: "#777777"; radius: 3
                TextInput {
                    anchors.fill: parent; anchors.margins: 5
                    text: root.absDownText
                    color: "black"; font.pointSize: 9
                    selectByMouse: true
                    validator: DoubleValidator { bottom: -99.0; top: 99.0; decimals: 4; notation: DoubleValidator.StandardNotation }
                    onTextChanged: root.absDownText = text
                }
            }
            Rectangle {
                x: 136; y: 174; width: 52; height: 24
                color: "#d0e8ff"; border.color: "#6699cc"; radius: 3
                Text { anchors.centerIn: parent; text: "Apply ↓"; font.pointSize: 7.5; font.bold: true; color: "#003366" }
                MouseArea { anchors.fill: parent; onClicked: applyAbsolute(false) }
            }
            Text { x: 196; y: 178; width: 158; text: "beamPos→0; offset.y"; font.pointSize: 7; color: "#666666" }

            Rectangle {
                x: 368; y: 146; width: 132; height: 52
                color: "#e8e0ff"; border.color: "#8266cc"; radius: 3
                Text {
                    anchors.centerIn: parent
                    text: "Save abs\ndefaults"
                    horizontalAlignment: Text.AlignHCenter
                    font.pointSize: 7.4; font.bold: true; color: "#2c1a66"
                }
                MouseArea { anchors.fill: parent; onClicked: saveAbsoluteDefaults() }
            }

            // ── A3: Slope / Reset ───────────────────────────────────────────
            Rectangle {
                x: 12; y: 210; width: 112; height: 26
                color: "#dddddd"; border.color: "#888888"; radius: 3
                Text { anchors.centerIn: parent; text: "Force horizontal"; font.pointSize: 7.5; color: "black" }
                MouseArea { anchors.fill: parent; onClicked: applyHorizontal() }
            }
            Rectangle {
                x: 130; y: 210; width: 100; height: 26
                color: "#dddddd"; border.color: "#888888"; radius: 3
                Text { anchors.centerIn: parent; text: "Restore slope"; font.pointSize: 7.5; color: "black" }
                MouseArea { anchors.fill: parent; onClicked: restoreSlope() }
            }
            Rectangle {
                x: 236; y: 210; width: 96; height: 26
                color: "#e8dddd"; border.color: "#aa7777"; radius: 3
                Text { anchors.centerIn: parent; text: "Reset Height"; font.pointSize: 7.5; font.bold: true; color: "#5a1a1a" }
                MouseArea { anchors.fill: parent; onClicked: resetHeight() }
            }
            Rectangle {
                x: 338; y: 210; width: 96; height: 26
                color: "#fff0cc"; border.color: "#b8860b"; radius: 3
                Text { anchors.centerIn: parent; text: "Factory Reset"; font.pointSize: 7.5; font.bold: true; color: "#5a3a00" }
                MouseArea { anchors.fill: parent; onClicked: factoryReset() }
            }

            // ════════════════════════════════════════════════════════════════
            // SECTION B — GROW BEAMS
            // ════════════════════════════════════════════════════════════════

            Text {
                x: 12; y: 250
                text: "B — Grow Beams"
                font.pointSize: 9; font.bold: true; color: "#333333"
            }
            Rectangle { x: 12; y: 264; width: 496; height: 1; color: "#aaaaaa" }

            Text { x: 12; y: 272; text: "Delta:"; font.pointSize: 8; font.bold: true; color: "#333333" }
            Rectangle {
                x: 52; y: 268; width: 62; height: 24
                color: "white"; border.color: "#777777"; radius: 3
                TextInput {
                    anchors.fill: parent; anchors.margins: 5
                    text: root.growDeltaText
                    color: "black"; font.pointSize: 9
                    selectByMouse: true
                    validator: DoubleValidator { bottom: 0.001; top: 19.0; decimals: 4; notation: DoubleValidator.StandardNotation }
                    onTextChanged: root.growDeltaText = text
                }
            }

            // L+R
            Text { x: 12; y: 302; text: "L+R:"; font.pointSize: 8; font.bold: true; color: "#1a4a1a" }
            Rectangle {
                x: 46; y: 297; width: 26; height: 24
                color: "#d8f0d8"; border.color: "#5a9a5a"; radius: 3
                Text { anchors.centerIn: parent; text: "▲"; font.pointSize: 10; color: "#1a4a1a" }
                MouseArea { anchors.fill: parent; onClicked: runGrowFactor(1.0 + parseGrowDelta(), true, true) }
            }
            Rectangle {
                x: 76; y: 297; width: 26; height: 24
                color: "#d8f0d8"; border.color: "#5a9a5a"; radius: 3
                Text { anchors.centerIn: parent; text: "▼"; font.pointSize: 10; color: "#1a4a1a" }
                MouseArea { anchors.fill: parent; onClicked: runGrowFactor(1.0 - parseGrowDelta(), true, true) }
            }

            // Left
            Text { x: 116; y: 302; text: "Left:"; font.pointSize: 8; font.bold: true; color: "#1a4a1a" }
            Rectangle {
                x: 150; y: 297; width: 26; height: 24
                color: "#d8f0d8"; border.color: "#5a9a5a"; radius: 3
                Text { anchors.centerIn: parent; text: "▲"; font.pointSize: 10; color: "#1a4a1a" }
                MouseArea { anchors.fill: parent; onClicked: runGrowFactor(1.0 + parseGrowDelta(), true, false) }
            }
            Rectangle {
                x: 180; y: 297; width: 26; height: 24
                color: "#d8f0d8"; border.color: "#5a9a5a"; radius: 3
                Text { anchors.centerIn: parent; text: "▼"; font.pointSize: 10; color: "#1a4a1a" }
                MouseArea { anchors.fill: parent; onClicked: runGrowFactor(1.0 - parseGrowDelta(), true, false) }
            }

            // Right
            Text { x: 220; y: 302; text: "Right:"; font.pointSize: 8; font.bold: true; color: "#1a4a1a" }
            Rectangle {
                x: 258; y: 297; width: 26; height: 24
                color: "#d8f0d8"; border.color: "#5a9a5a"; radius: 3
                Text { anchors.centerIn: parent; text: "▲"; font.pointSize: 10; color: "#1a4a1a" }
                MouseArea { anchors.fill: parent; onClicked: runGrowFactor(1.0 + parseGrowDelta(), false, true) }
            }
            Rectangle {
                x: 288; y: 297; width: 26; height: 24
                color: "#d8f0d8"; border.color: "#5a9a5a"; radius: 3
                Text { anchors.centerIn: parent; text: "▼"; font.pointSize: 10; color: "#1a4a1a" }
                MouseArea { anchors.fill: parent; onClicked: runGrowFactor(1.0 - parseGrowDelta(), false, true) }
            }

            Text { x: 12; y: 330; text: "0.05 = ±5% per click"; font.pointSize: 7.5; color: "#555555" }

            Rectangle {
                x: 12; y: 344; width: 92; height: 26
                color: "#e8dddd"; border.color: "#aa7777"; radius: 3
                Text { anchors.centerIn: parent; text: "Reset Grow"; font.pointSize: 7.2; font.bold: true; color: "#5a1a1a" }
                MouseArea { anchors.fill: parent; onClicked: resetGrow() }
            }
            Rectangle {
                x: 110; y: 344; width: 92; height: 26
                color: "#d8f0d8"; border.color: "#5a9a5a"; radius: 3
                Text { anchors.centerIn: parent; text: "Joint beams"; font.pointSize: 7.2; font.bold: true; color: "#1a4a1a" }
                MouseArea { anchors.fill: parent; onClicked: jointGrowBeams() }
            }
            Rectangle {
                x: 208; y: 344; width: 100; height: 26
                color: "#fff0cc"; border.color: "#b8860b"; radius: 3
                Text { anchors.centerIn: parent; text: "Factory Reset"; font.pointSize: 7.2; font.bold: true; color: "#5a3a00" }
                MouseArea { anchors.fill: parent; onClicked: factoryResetGrow() }
            }
            Text {
                x: 316; y: 340; width: 192; height: 36
                text: "Reset=baseline session · Joint=0 · Factory=1.0"
                wrapMode: Text.WordWrap
                font.pointSize: 6.8; color: "#666666"
            }

            // ════════════════════════════════════════════════════════════════
            // SECTION C — SELECT BEAMS
            // ════════════════════════════════════════════════════════════════
            Text {
                x: 12; y: 384
                text: "C — Select Beams"
                font.pointSize: 9; font.bold: true; color: "#333333"
            }
            Rectangle { x: 12; y: 398; width: 496; height: 1; color: "#aaaaaa" }

            Rectangle {
                x: 12; y: 410; width: 122; height: 28
                color: "#d0e8ff"; border.color: "#6699cc"; radius: 3
                Text { anchors.centerIn: parent; text: "Select up=true"; font.pointSize: 7.5; font.bold: true; color: "#003366" }
                MouseArea { anchors.fill: parent; onClicked: scheduleSelectBeamsByUp(true) }
            }
            Rectangle {
                x: 140; y: 410; width: 122; height: 28
                color: "#d0e8ff"; border.color: "#6699cc"; radius: 3
                Text { anchors.centerIn: parent; text: "Select up=false"; font.pointSize: 7.5; font.bold: true; color: "#003366" }
                MouseArea { anchors.fill: parent; onClicked: scheduleSelectBeamsByUp(false) }
            }
            Text {
                x: 272; y: 408; width: 236; height: 34
                text: "Direct Beam-object selection first; anchor fallback only if MS4 rejects Beam selection."
                wrapMode: Text.WordWrap
                font.pointSize: 6.8; color: "#666666"
            }

            // ════════════════════════════════════════════════════════════════
            // SECTION D — ISOLATED STEMS
            // ════════════════════════════════════════════════════════════════
            Text {
                x: 12; y: 452
                text: "D — Isolated Stems"
                font.pointSize: 9; font.bold: true; color: "#333333"
            }
            Rectangle { x: 12; y: 466; width: 496; height: 1; color: "#aaaaaa" }

            Text { x: 12; y: 478; text: "Stem delta:"; font.pointSize: 8; font.bold: true; color: "#333333" }
            Rectangle {
                x: 84; y: 474; width: 64; height: 24
                color: "white"; border.color: "#777777"; radius: 3
                TextInput {
                    anchors.fill: parent; anchors.margins: 5
                    text: root.stemFactorText
                    color: "black"; font.pointSize: 9
                    selectByMouse: true
                    validator: DoubleValidator { bottom: 0.0001; top: 20.0; decimals: 4; notation: DoubleValidator.StandardNotation }
                    onTextChanged: root.stemFactorText = text
                }
            }
            Text { x: 156; y: 478; width: 340; text: "0.05 = 5% of visual stem; ▲ increments, ▼ decrements"; font.pointSize: 7.5; color: "#555555" }

            Rectangle {
                x: 12; y: 510; width: 92; height: 28
                color: "#e4e4e4"; border.color: "#777777"; radius: 3
                Text { anchors.centerIn: parent; text: "Diagnose D"; font.pointSize: 7.5; color: "black" }
                MouseArea { anchors.fill: parent; onClicked: diagnoseStems() }
            }
            Rectangle {
                x: 110; y: 510; width: 44; height: 28
                color: "#d8f0d8"; border.color: "#5a9a5a"; radius: 3
                Text { anchors.centerIn: parent; text: "▲"; font.pointSize: 10; font.bold: true; color: "#1a4a1a" }
                MouseArea { anchors.fill: parent; onClicked: applyStemDeltaArrow(1) }
            }
            Rectangle {
                x: 160; y: 510; width: 44; height: 28
                color: "#d8f0d8"; border.color: "#5a9a5a"; radius: 3
                Text { anchors.centerIn: parent; text: "▼"; font.pointSize: 10; font.bold: true; color: "#1a4a1a" }
                MouseArea { anchors.fill: parent; onClicked: applyStemDeltaArrow(-1) }
            }
            Rectangle {
                x: 210; y: 510; width: 112; height: 28
                color: "#e8dddd"; border.color: "#aa7777"; radius: 3
                Text { anchors.centerIn: parent; text: "Reset stems"; font.pointSize: 7.5; font.bold: true; color: "#5a1a1a" }
                MouseArea { anchors.fill: parent; onClicked: resetIsolatedStemsToDefault() }
            }

            Rectangle {
                x: 12; y: 546; width: 128; height: 26
                color: includeGraceNotes ? "#cfcfcf" : "#eeeeee"; border.color: "#777777"; radius: 3
                Text { anchors.centerIn: parent; text: includeGraceNotes ? "Grace: include" : "Grace: ignore"; color:"black"; font.pointSize: 7.2 }
                MouseArea { anchors.fill: parent; onClicked: { includeGraceNotes = !includeGraceNotes } }
            }
            Text {
                x: 150; y: 544; width: 358; height: 34
                text: "Only isolated stems: beamed chords are ignored. Grace include also scans graceNotes attached to selected chords."
                wrapMode: Text.WordWrap
                font.pointSize: 6.8; color: "#666666"
            }

            // ════════════════════════════════════════════════════════════════
            // SECTION E — RESTORE ADVANCEDBEAMS
            // ════════════════════════════════════════════════════════════════
            Text {
                x: 12; y: 586
                text: "E — Restore AdvancedBeams"
                font.pointSize: 9; font.bold: true; color: "#333333"
            }
            Rectangle { x: 12; y: 600; width: 496; height: 1; color: "#aaaaaa" }

            Rectangle {
                x: 12; y: 612; width: 96; height: 28
                color: "#d0e8ff"; border.color: "#6699cc"; radius: 3
                Text { anchors.centerIn: parent; text: "Save snap"; font.pointSize: 7.5; font.bold: true; color: "#003366" }
                MouseArea { anchors.fill: parent; onClicked: saveSnapshot() }
            }
            Rectangle {
                x: 114; y: 612; width: 104; height: 28
                color: "#d7ffd7"; border.color: "#66aa66"; radius: 3
                Text { anchors.centerIn: parent; text: "Restore snap"; font.pointSize: 7.5; font.bold: true; color: "#114411" }
                MouseArea { anchors.fill: parent; onClicked: restoreSnapshot() }
            }
            Rectangle {
                x: 224; y: 612; width: 86; height: 28
                color: "#ffffff"; border.color: "#777777"; radius: 3
                Text { anchors.centerIn: parent; text: "Diagnose E"; font.pointSize: 7.2; color: "#222222" }
                MouseArea { anchors.fill: parent; onClicked: diagnoseSnapshotSelection() }
            }
            Rectangle {
                x: 316; y: 612; width: 78; height: 28
                color: "#ffffff"; border.color: "#777777"; radius: 3
                Text { anchors.centerIn: parent; text: "Load file"; font.pointSize: 7.2; color: "#222222" }
                MouseArea { anchors.fill: parent; onClicked: loadSnapshotFromFile(true) }
            }
            Rectangle {
                x: 400; y: 612; width: 100; height: 28
                color: "#ffe0e0"; border.color: "#cc7777"; radius: 3
                Text { anchors.centerIn: parent; text: "Clear snap"; font.pointSize: 7.2; color: "#662222" }
                MouseArea { anchors.fill: parent; onClicked: clearSnapshot() }
            }

            Text {
                x: 12; y: 646; width: 496; height: 38
                text: snapshotSummaryText()
                wrapMode: Text.WordWrap
                font.pointSize: 6.8; color: "#555555"; clip: true
            }

            // ════════════════════════════════════════════════════════════════
            // FOOTER
            // ════════════════════════════════════════════════════════════════
            Rectangle { x: 12; y: 696; width: 496; height: 1; color: "#aaaaaa" }

            Rectangle {
                x: 12; y: 706; width: 96; height: 28
                color: "#dddddd"; border.color: "#888888"; radius: 3
                Text { anchors.centerIn: parent; text: "Diagnose"; font.pointSize: 8; color: "black" }
                MouseArea { anchors.fill: parent; onClicked: diagnose() }
            }
            Rectangle {
                x: 114; y: 706; width: 112; height: 28
                color: "#e8dddd"; border.color: "#aa7777"; radius: 3
                Text { anchors.centerIn: parent; text: "Reset All"; font.pointSize: 8; font.bold: true; color: "#5a1a1a" }
                MouseArea { anchors.fill: parent; onClicked: resetAll() }
            }
            Rectangle {
                x: 232; y: 706; width: 76; height: 28
                color: "#eeeeee"; border.color: "#888888"; radius: 3
                Text { anchors.centerIn: parent; text: "Close"; font.pointSize: 8; color: "black" }
                MouseArea { anchors.fill: parent; onClicked: smartQuit() }
            }

            Text {
                x: 12; y: 744; width: 496; height: 58
                text: "A/B/D edit beams and isolated stems. C filters selection by up=true/false using anchors when MS4 rejects direct Beam selection. E: Save snap before time-signature/reset operations; Restore snap after selecting the corresponding range. Reset All only restores the current session baseline for A/B."
                wrapMode: Text.WordWrap; font.pointSize: 6.4; color: "#666666"; clip: true
            }
        }
    }

    // Visual vertical scrollbar / scroll indicator.
    // Uses only QtQuick/Flickable to avoid adding QtQuick.Controls dependencies.
    Rectangle {
        id: scrollTrack
        x: root.width - 8
        y: 0
        width: 8
        height: root.height
        color: "#e0e0e0"
        opacity: 0.75
        visible: mainFlick.contentHeight > mainFlick.height
        z: 1000

        MouseArea {
            anchors.fill: parent
            onClicked: {
                var maxY = Math.max(1, mainFlick.contentHeight - mainFlick.height)
                var ratio = mouse.y / Math.max(1, scrollTrack.height)
                mainFlick.contentY = Math.max(0, Math.min(maxY, ratio * maxY))
            }
        }
    }

    Rectangle {
        id: scrollThumb
        x: root.width - 8
        y: mainFlick.visibleArea.yPosition * scrollTrack.height
        width: 8
        height: Math.max(36, mainFlick.visibleArea.heightRatio * scrollTrack.height)
        radius: 4
        color: "#888888"
        visible: scrollTrack.visible
        z: 1001
    }

    // ═══════════════════════════════════════════════════════════════════════
    // HELPERS
    // ═══════════════════════════════════════════════════════════════════════

    function smartQuit() {
        if (mscoreMajorVersion < 4) Qt.quit()
        else quit()
    }

    function parseNumber(s, fallback) {
        var f = Number(("" + s).replace(",", "."))
        return isFinite(f) ? f : fallback
    }

    function parseHeightDelta() {
        var d = Math.abs(parseNumber(heightDeltaText, 0.05))
        return (isFinite(d) && d > 0) ? d : 0.05
    }

    function parseGrowDelta() {
        var d = Math.abs(parseNumber(growDeltaText, 0.05))
        return (isFinite(d) && d > 0) ? d : 0.05
    }

    function parseAbsUp() {
        return parseNumber(absUpText, -4.0)
    }

    function parseAbsDown() {
        return parseNumber(absDownText, 4.0)
    }

    function parseStrictNumber(s) {
        var f = Number(("" + s).replace(",", "."))
        return isFinite(f) ? f : NaN
    }

    function numberToText(n) {
        var x = Number(n)
        if (!isFinite(x)) return "0"
        var rounded = Math.round(x * 10000) / 10000
        return "" + rounded
    }

    function normalizePath(p) {
        var s = "" + p
        return s.replace(/\\/g, "/")
    }

    function defaultsFileCandidates() {
        var out = []
        try {
            if (root.filePath && root.filePath !== "")
                out.push(normalizePath(root.filePath) + "/AdvancedBeams_abs_defaults.txt")
        } catch(e0) {}
        try {
            var h = normalizePath(absDefaultsFile.homePath())
            if (h && h !== "") {
                out.push(h + "/AdvancedBeams_abs_defaults.txt")
                out.push(h + "/Documents/AdvancedBeams_abs_defaults.txt")
            }
        } catch(e1) {}
        try {
            var t = normalizePath(absDefaultsFile.tempPath())
            if (t && t !== "")
                out.push(t + "/AdvancedBeams_abs_defaults.txt")
        } catch(e2) {}
        return out
    }

    function ensureDefaultsFileSource() {
        try {
            if (absDefaultsFile.source && absDefaultsFile.source !== "") return true
            var candidates = defaultsFileCandidates()
            if (!candidates || candidates.length === 0) return false

            // Prefer an already existing defaults file, wherever it was saved.
            for (var i = 0; i < candidates.length; i++) {
                try {
                    absDefaultsFile.source = candidates[i]
                    if (absDefaultsFile.exists()) return true
                } catch(eExists) {}
            }

            // For a new file, prefer the plugin folder. In MuseScore this is
            // normally the user plugin directory and is usually writable.
            absDefaultsFile.source = candidates[0]
            return true
        } catch(e) {
            return false
        }
    }

    function loadAbsoluteDefaults() {
        try {
            if (!ensureDefaultsFileSource()) return
            if (!absDefaultsFile.exists()) return

            var data = absDefaultsFile.read()
            if (!data || data === "") return

            var lines = data.split(/\r?\n/)
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i]
                var eq = line.indexOf("=")
                if (eq < 0) continue
                var key = line.substring(0, eq)
                var val = line.substring(eq + 1)
                var n = parseStrictNumber(val)
                if (!isFinite(n)) continue
                if (key === "up")   absUpText = numberToText(n)
                if (key === "down") absDownText = numberToText(n)
            }
        } catch(e) {
            // Keep built-in defaults if loading fails.
        }
    }

    function saveAbsoluteDefaults() {
        var upVal = parseStrictNumber(absUpText)
        var downVal = parseStrictNumber(absDownText)
        if (!isFinite(upVal) || !isFinite(downVal)) {
            statusMsg = "Invalid absolute default. Check both Up and Down fields."
            return
        }

        var upText = numberToText(upVal)
        var downText = numberToText(downVal)
        var data = "up=" + upText + "\n" + "down=" + downText + "\n"
        var candidates = defaultsFileCandidates()
        if (!candidates || candidates.length === 0) {
            statusMsg = "Could not access any defaults file path."
            return
        }

        var tried = []
        var lastErr = ""
        for (var i = 0; i < candidates.length; i++) {
            try {
                fileIoLastError = ""
                absDefaultsFile.source = candidates[i]
                tried.push(candidates[i])
                if (absDefaultsFile.write(data)) {
                    absUpText = upText
                    absDownText = downText
                    statusMsg = "Saved custom absolute defaults: up=true " + upText
                              + "; up=false " + downText
                              + ". File: " + candidates[i]
                    return
                }
                if (fileIoLastError && fileIoLastError !== "") lastErr = fileIoLastError
            } catch(e) {
                lastErr = "" + e
            }
        }

        statusMsg = "Could not write absolute defaults file. Tried " + tried.length
                  + " paths" + (lastErr !== "" ? ": " + lastErr : ".")
    }

    function fmt(n) {
        var x = Number(n)
        return isFinite(x) ? x.toFixed(3) : "?"
    }

    function parsePair(v) {
        var out = { ok: false, l: 0, r: 0 }
        try {
            if (!v) return out
            if (typeof v.x !== "undefined") {
                var xx = Number(v.x), yy = Number(v.y)
                if (isFinite(xx) && isFinite(yy)) { out.ok=true; out.l=xx; out.r=yy; return out }
            }
            if (typeof v.first !== "undefined") {
                var ff = Number(v.first), ss = Number(v.second)
                if (isFinite(ff) && isFinite(ss)) { out.ok=true; out.l=ff; out.r=ss; return out }
            }
            var s = "" + v
            var a = s.indexOf("("), b = s.lastIndexOf(")")
            var inside = (a >= 0 && b > a) ? s.substring(a+1, b) : s
            var nums = inside.match(/[-+]?\d+(?:[\.,]\d+)?(?:[eE][-+]?\d+)?/g)
            if (nums && nums.length >= 2) {
                var n1 = Number((""+nums[0]).replace(",",".")), n2 = Number((""+nums[1]).replace(",","."))
                if (isFinite(n1) && isFinite(n2)) { out.ok=true; out.l=n1; out.r=n2 }
            }
        } catch(e) {}
        return out
    }

    function readBeamPos(beam) {
        try { return parsePair(beam.beamPos) } catch(e) { return {ok:false,l:0,r:0} }
    }

    function writeBeamPos(beam, leftVal, rightVal) {
        if (!beam) return false
        var l = Number(leftVal)
        var r = Number(rightVal)
        if (!isFinite(l) || !isFinite(r)) return false

        // In QML, Qt.point(l, r) is passed as a QVariant/QPointF-like value to the
        // beamPos setter. This is the practical way to feed setBeamPos() from a plugin.
        var assigned = false
        try {
            beam.beamPos = Qt.point(l, r)
            assigned = true
        } catch(e0) {
            assigned = false
        }

        // Fallback for environments that expose a mutable point-like object.
        if (!assigned) {
            try {
                var bp = beam.beamPos
                if (bp && typeof bp.x !== "undefined") {
                    bp.x = l
                    bp.y = r
                    beam.beamPos = bp
                    assigned = true
                }
            } catch(e1) {
                assigned = false
            }
        }

        if (!assigned) return false

        // Verify when the getter is readable. If it is not readable, trust the assignment.
        var after = readBeamPos(beam)
        if (!after.ok) return true
        return Math.abs(after.l - l) < 0.001 && Math.abs(after.r - r) < 0.001
    }

    function clearOffsetYKeepX(beam) {
        try {
            var off = getOffset(beam)
            beam.offset = Qt.point(off.x, 0)
            return true
        } catch(e) {}
        return false
    }

    function restoreBeamPosFromState(s) {
        if (!s || !s.beam || !s.bpOk) return false
        return writeBeamPos(s.beam, s.bpL, s.bpR)
    }

    function getOffset(beam) {
        var out = {x:0, y:0}
        try {
            if (beam && beam.offset) {
                var ox = Number(beam.offset.x), oy = Number(beam.offset.y)
                out.x = isFinite(ox) ? ox : 0
                out.y = isFinite(oy) ? oy : 0
            }
        } catch(e) {}
        return out
    }

    function readBool(beam, prop) {
        try {
            var v = beam[prop]
            if (typeof v === "boolean") return v
            if (typeof v === "string")  return v === "true"
        } catch(e) {}
        return false
    }

    function ensureUserModified(beam) {
        if (!beam) return false
        var ok = false
        try {
            beam.userModified = true
            ok = true
        } catch(e0) {
            ok = false
        }
        try {
            if (readBool(beam, "userModified")) return true
        } catch(e1) {}
        return ok
    }

    function primeManualBeam(beam) {
        if (!beam) return false
        var ok = false
        var off = getOffset(beam)

        // Delta works because it writes offset after setting userModified.
        // Force horizontal needs the same kind of concrete write; otherwise MS4
        // often keeps later beam groups as automatic even when the flag was set.
        try { beam.userModified = true; ok = true } catch(e0) {}

        // First try an exact rewrite of the current offset.
        try { beam.offset = Qt.point(off.x, off.y); ok = true } catch(e1) {}

        // Some builds optimise a no-op property write away. A tiny nudge followed
        // immediately by the original value forces the beam into the editable path
        // without leaving a visible displacement.
        try {
            var eps = 0.0001
            beam.offset = Qt.point(off.x, off.y + eps)
            beam.offset = Qt.point(off.x, off.y)
            ok = true
        } catch(e2) {}

        try {
            if (readBool(beam, "userModified")) return true
        } catch(e3) {}
        return ok
    }

    function readUp(beam) {
        // beam.up: true = stems up = beam above notes
        return readBool(beam, "up")
    }

    function readGrow(beam) {
        var gl = 0, gr = 0
        try { gl = Number(beam.growLeft)  || 0 } catch(e) {}
        try { gr = Number(beam.growRight) || 0 } catch(e) {}
        return { l: isFinite(gl)?gl:0, r: isFinite(gr)?gr:0 }
    }

    function sameElement(a, b) {
        if (!a || !b) return false

        // Important: do NOT use Element.is() or pagePos as equality tests here.
        // In MuseScore 4 QML, Element.is() is not a reliable object-identity
        // comparator for this use, and Beam.pagePos can be identical/default-like
        // across different beam groups. Either fallback can collapse a whole
        // range selection into the first beam group only. Strict JS object
        // identity is safer: when QML gives the same Beam object, we dedupe it;
        // otherwise repeated writes are harmless for absolute/horizontal/reset.
        return a === b
    }

    function findSavedIndex(beam) {
        for (var i = 0; i < savedStates.length; i++)
            if (sameElement(savedStates[i].beam, beam)) return i
        return -1
    }

    function saveInitialStateIfNeeded(beam) {
        if (!beam || findSavedIndex(beam) >= 0) return
        var off  = getOffset(beam)
        var bp   = readBeamPos(beam)
        var grow = readGrow(beam)
        savedStates.push({
            beam:       beam,
            offX:       off.x,
            offY:       off.y,
            bpOk:       bp.ok,
            bpL:        bp.l,
            bpR:        bp.r,
            wasUserMod: readBool(beam, "userModified"),
            wasNoSlope: readBool(beam, "beamNoSlope"),
            growL:      grow.l,
            growR:      grow.r
        })
    }

    function isChord(el) { return el && el.type === Element.CHORD }
    function isRest(el)  { return el && el.type === Element.REST }
    function isBeam(el)  { return el && el.type === Element.BEAM }

    function findChordFromElement(el) {
        var e = el
        for (var i = 0; i < 10 && e; i++) {
            if (isChord(e)) return e
            try { e = e.parent } catch(err) { e = null }
        }
        return null
    }

    // ═══════════════════════════════════════════════════════════════════════
    // COLLECT BEAMS
    // ═══════════════════════════════════════════════════════════════════════

    function collectBeams() {
        var result = { beams: [], chordsTotal: 0, beamedChords: 0 }
        var sel = null
        try { sel = curScore.selection } catch(e) { return result }
        if (!sel) return result

        function addBeam(beam) {
            if (!beam) return
            for (var i = 0; i < result.beams.length; i++)
                if (sameElement(result.beams[i], beam)) return
            result.beams.push(beam)
        }

        function addFromEl(el) {
            if (!el) return
            result.chordsTotal++
            var beam = null
            try { beam = el.beam } catch(eB) {}
            if (!beam) return
            result.beamedChords++
            addBeam(beam)
        }

        try {
            if (sel.isRange && sel.startSegment) {
                var seg     = sel.startSegment
                var endTick = sel.endSegment ? sel.endSegment.tick : 2147483647
                var stStart  = (typeof sel.startStaff !== "undefined" && sel.startStaff >= 0) ? sel.startStaff : 0
                // MuseScore 4 exposes endStaff as an exclusive upper bound.
                // Example: a range on staff n reports startStaff=n, endStaff=n+1.
                // Subtract 1 before using <= loops, otherwise operations leak to
                // the next lower staff.
                var stEndRaw = (typeof sel.endStaff !== "undefined" && sel.endStaff >= stStart) ? sel.endStaff : stStart
                var stEnd    = (stEndRaw > stStart) ? (stEndRaw - 1) : stStart
                var guard    = 0
                while (seg && seg.tick < endTick && guard < 50000) {
                    for (var st = stStart; st <= stEnd; st++) {
                        for (var v = 0; v < 4; v++) {
                            var el = null
                            try { el = seg.elementAt(st * 4 + v) } catch(e1) {}
                            if (isChord(el) || isRest(el)) addFromEl(el)
                        }
                    }
                    try { seg = seg.next } catch(eN) { break }
                    guard++
                }
            }
        } catch(eRange) {}

        // Also scan selection.elements even for range selections. In some MS4
        // builds, start/end segment traversal can be incomplete for edited beams;
        // selection.elements often still exposes the selected chords/notes.
        try {
            var elems = sel.elements
            if (elems) {
                for (var k = 0; k < elems.length; k++) {
                    var e = elems[k]
                    if (!e) continue
                    if (isBeam(e)) { addBeam(e); continue }
                    var ch = findChordFromElement(e)
                    if (ch) addFromEl(ch)
                }
            }
        } catch(eElems) {}

        return result
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION A — BEAM HEIGHT
    // ═══════════════════════════════════════════════════════════════════════

    function isManualBeam(beam) {
        var bp = readBeamPos(beam)
        return bp.ok && (Math.abs(bp.l) > 0.0001 || Math.abs(bp.r) > 0.0001)
    }

    function referenceMid(beam) {
        var bp = readBeamPos(beam)
        if (bp.ok && (Math.abs(bp.l) > 0.0001 || Math.abs(bp.r) > 0.0001))
            return (bp.l + bp.r) / 2.0
        return -3.0
    }

    function runHeightDelta(delta) {
        if (!isFinite(delta) || Math.abs(delta) < 0.000001) { statusMsg = "Invalid delta."; return }
        var d = collectBeams()
        if (d.beams.length === 0) { statusMsg = "No beams found in selection."; return }
        var ok = 0, fail = 0, upCount = 0, downCount = 0
        try {
            curScore.startCmd()
            for (var i = 0; i < d.beams.length; i++) {
                var beam = d.beams[i]
                saveInitialStateIfNeeded(beam)
                var off = getOffset(beam)
                var isUp = readUp(beam)
                var signedDelta = isUp ? -delta : delta
                if (isUp) upCount++; else downCount++
                try { ensureUserModified(beam) } catch(eUM) {}
                var newOffY = off.y + signedDelta
                if (!isFinite(newOffY)) { fail++; continue }
                try { beam.offset = Qt.point(off.x, newOffY); ok++ } catch(e) { fail++ }
            }
            try { curScore.doLayout() } catch(eL) {}
            curScore.endCmd()
        } catch(err) {
            try { curScore.endCmd() } catch(ig) {}
            statusMsg = "Error: " + err; return
        }
        var deltaStr = delta >= 0 ? "+" + fmt(delta) : fmt(delta)
        statusMsg = "A delta " + deltaStr + " applied by beam.up: up=true receives inverse sign; up="
                  + upCount + " down=" + downCount + ". OK=" + ok + " fail=" + fail
                  + " · saved=" + savedStates.length + "."
    }

    function runHeightDeltaFiltered(delta, upDirection) {
        if (!isFinite(delta) || Math.abs(delta) < 0.000001) { statusMsg = "Invalid delta."; return }
        var d = collectBeams()
        if (d.beams.length === 0) { statusMsg = "No beams found in selection."; return }

        var targets = []
        var skipped = 0
        for (var t = 0; t < d.beams.length; t++) {
            var b = d.beams[t]
            if (readUp(b) === upDirection) targets.push(b)
            else skipped++
        }
        if (targets.length === 0) {
            statusMsg = "A delta: no beams with up=" + upDirection + " found. collected="
                      + d.beams.length + " skipped=" + skipped + "."
            return
        }

        var ok = 0, fail = 0
        try {
            curScore.startCmd()
            for (var i = 0; i < targets.length; i++) {
                var beam = targets[i]
                saveInitialStateIfNeeded(beam)
                var off = getOffset(beam)
                var signedDelta = upDirection ? -delta : delta
                try { ensureUserModified(beam) } catch(eUM) {}
                var newOffY = off.y + signedDelta
                if (!isFinite(newOffY)) { fail++; continue }
                try { beam.offset = Qt.point(off.x, newOffY); ok++ } catch(e) { fail++ }
            }
            try { curScore.doLayout() } catch(eL) {}
            curScore.endCmd()
        } catch(err) {
            try { curScore.endCmd() } catch(ig) {}
            statusMsg = "Error: " + err; return
        }
        var deltaStr = delta >= 0 ? "+" + fmt(delta) : fmt(delta)
        statusMsg = "A delta filtered up=" + upDirection + " " + deltaStr
                  + " applied with direction sign. targets=" + targets.length
                  + " skipped=" + skipped + " OK=" + ok + " fail=" + fail
                  + " · saved=" + savedStates.length + "."
    }

    function applyAbsolute(upDirection) {
        var absVal = upDirection ? parseAbsUp() : parseAbsDown()
        if (!isFinite(absVal)) { statusMsg = "Invalid absolute value."; return }
        var d = collectBeams()
        if (d.beams.length === 0) { statusMsg = "No beams found in selection."; return }

        // Build the target list BEFORE any write/layout. Direction filtering must
        // see the original selection, not a selection already modified by the
        // first beam touched.
        var targets = []
        var skip = 0
        for (var t = 0; t < d.beams.length; t++) {
            var b = d.beams[t]
            if (readUp(b) === upDirection) targets.push(b)
            else skip++
        }
        if (targets.length === 0) {
            statusMsg = "No " + (upDirection ? "up" : "down") + " beams found in selection. collected="
                      + d.beams.length + " skipped=" + skip + "."
            return
        }

        var ok = 0, fail = 0, bpZeroFail = 0, primeOk = 0, primeFail = 0

        // Phase 1: prime ALL target beam groups. This deliberately writes offset
        // like the working delta function, so userModified is committed for every
        // group before the absolute value is applied.
        try {
            curScore.startCmd()
            for (var i = 0; i < targets.length; i++) {
                var beam0 = targets[i]
                saveInitialStateIfNeeded(beam0)
                if (primeManualBeam(beam0)) primeOk++; else primeFail++
            }
            try { curScore.doLayout() } catch(ePrimeLayout) {}
            curScore.endCmd()
        } catch(errPrime) {
            try { curScore.endCmd() } catch(ig0) {}
            statusMsg = "Error priming absolute: " + errPrime; return
        }

        // Phase 2: zero beamPos, then write the requested absolute y through offset.
        try {
            curScore.startCmd()
            for (var j = 0; j < targets.length; j++) {
                var beam = targets[j]
                try { beam.userModified = true } catch(eUM2) {}

                var bpOk = writeBeamPos(beam, 0, 0)
                if (!bpOk) bpZeroFail++

                var off = getOffset(beam)
                try {
                    beam.offset = Qt.point(off.x, absVal)
                    ok++
                } catch(e) {
                    fail++
                }
            }
            try { curScore.doLayout() } catch(eL) {}
            curScore.endCmd()
        } catch(err) {
            try { curScore.endCmd() } catch(ig) {}
            statusMsg = "Error applying absolute: " + err; return
        }
        var dir = upDirection ? "up" : "down"
        statusMsg = "A absolute " + dir + ": primed=" + primeOk + "/" + targets.length
                  + ", beamPos→0, offset.y=" + fmt(absVal)
                  + ". OK=" + ok + " skipped=" + skip + " fail=" + fail
                  + " bp0fail=" + bpZeroFail + "."
    }

    function applyHorizontal() {
        var d = collectBeams()
        if (d.beams.length === 0) { statusMsg = "No beams found."; return }
        var ok = 0, fail = 0, primeOk = 0, primeFail = 0

        // Phase 1: commit userModified on ALL beams with a harmless offset write.
        try {
            curScore.startCmd()
            for (var i = 0; i < d.beams.length; i++) {
                var beam0 = d.beams[i]
                saveInitialStateIfNeeded(beam0)
                if (primeManualBeam(beam0)) primeOk++; else primeFail++
            }
            try { curScore.doLayout() } catch(ePrimeLayout) {}
            curScore.endCmd()
        } catch(errPrime) {
            try { curScore.endCmd() } catch(ig0) {}
            statusMsg = "Error priming horizontal: " + errPrime; return
        }

        // Phase 2: after the manual state exists for all beam groups, force no slope.
        try {
            curScore.startCmd()
            for (var j = 0; j < d.beams.length; j++) {
                var beam = d.beams[j]
                try {
                    beam.userModified = true
                    beam.beamNoSlope = true
                    ok++
                } catch(e) { fail++ }
            }
            try { curScore.doLayout() } catch(eL) {}
            curScore.endCmd()
        } catch(err) { try { curScore.endCmd() } catch(ig) {}; statusMsg = "Error applying horizontal: "+err; return }
        statusMsg = "A: horizontal forced after priming all beams. OK=" + ok
                  + " fail=" + fail + " primed=" + primeOk + "/" + d.beams.length + "."
    }

    function restoreSlope() {
        var d = collectBeams()
        if (d.beams.length === 0) { statusMsg = "No beams found."; return }
        var ok = 0, fail = 0, primeOk = 0
        try {
            curScore.startCmd()
            for (var i = 0; i < d.beams.length; i++) {
                var beam = d.beams[i]
                saveInitialStateIfNeeded(beam)
                if (primeManualBeam(beam)) primeOk++
            }
            try { curScore.doLayout() } catch(ePrimeLayout) {}
            curScore.endCmd()
        } catch(errPrime) { try { curScore.endCmd() } catch(ig0) {}; statusMsg = "Error priming slope restore: "+errPrime; return }

        try {
            curScore.startCmd()
            for (var j = 0; j < d.beams.length; j++) {
                var beam2 = d.beams[j]
                try { beam2.userModified = true; beam2.beamNoSlope = false; ok++ } catch(e) { fail++ }
            }
            try { curScore.doLayout() } catch(eL) {}
            curScore.endCmd()
        } catch(err) { try { curScore.endCmd() } catch(ig) {}; statusMsg = "Error restoring slope: "+err; return }
        statusMsg = "A: slope restored after priming. OK=" + ok + " fail=" + fail
                  + " primed=" + primeOk + "/" + d.beams.length + "."
    }

    function resetHeight() {
        if (!savedStates || savedStates.length === 0) {
            statusMsg = "Nothing saved for reset. State is captured on first apply."
            return
        }
        var ok = 0, fail = 0
        try {
            curScore.startCmd()
            for (var i = 0; i < savedStates.length; i++) {
                var s = savedStates[i]
                try {
                    if (!s || !s.beam) { fail++; continue }
                    try { restoreBeamPosFromState(s) } catch(eBP) {}
                    s.beam.offset = Qt.point(s.offX, s.offY)
                    try { s.beam.userModified = s.wasUserMod } catch(e1) {}
                    try { s.beam.beamNoSlope  = s.wasNoSlope } catch(e2) {}
                    ok++
                } catch(e0) { fail++ }
            }
            try { curScore.doLayout() } catch(eL) {}
            curScore.endCmd()
        } catch(err) {
            try { curScore.endCmd() } catch(ig) {}
            statusMsg = "Error: " + err; return
        }
        statusMsg = "A: height reset to initial state. OK=" + ok + " fail=" + fail + "."
    }

    function factoryReset() {
        var d = collectBeams()
        if (d.beams.length === 0) { statusMsg = "No beams found."; return }
        var ok = 0, fail = 0
        try {
            curScore.startCmd()
            for (var i = 0; i < d.beams.length; i++) {
                var beam = d.beams[i]
                try {
                    // Section A only: Beam Height + Force Horizontal/Slope state.
                    try { writeBeamPos(beam, 0, 0) } catch(eBP) {}
                    try { beam.offset = Qt.point(0, 0) } catch(eOff) {}
                    try { beam.beamNoSlope = false } catch(eSlope) {}
                    try { beam.userModified = false } catch(eUM) {}
                    ok++
                } catch(e) { fail++ }
            }
            try { curScore.doLayout() } catch(eL) {}
            curScore.endCmd()
        } catch(err) {
            try { curScore.endCmd() } catch(ig) {}
            statusMsg = "Error: " + err; return
        }
        statusMsg = "A Factory Reset: beam height and horizontal forcing reset. OK="
                  + ok + " fail=" + fail + "."
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION B — GROW BEAMS
    // ═══════════════════════════════════════════════════════════════════════

    function runGrowFactor(factor, applyLeft, applyRight) {
        if (!isFinite(factor) || factor === 0) { statusMsg = "Invalid delta."; return }
        var d = collectBeams()
        if (d.beams.length === 0) { statusMsg = "No beams found in selection."; return }
        var ok = 0, fail = 0
        try {
            curScore.startCmd()
            for (var i = 0; i < d.beams.length; i++) {
                var beam = d.beams[i]
                saveInitialStateIfNeeded(beam)
                var grow = readGrow(beam)
                var delta = factor - 1.0
                try {
                    if (applyLeft)
                        beam.growLeft  = (Math.abs(grow.l) < 0.0001) ? delta : grow.l * factor
                    if (applyRight)
                        beam.growRight = (Math.abs(grow.r) < 0.0001) ? delta : grow.r * factor
                    ok++
                } catch(e) { fail++ }
            }
            try { curScore.doLayout() } catch(eL) {}
            curScore.endCmd()
        } catch(err) {
            try { curScore.endCmd() } catch(ig) {}
            statusMsg = "Error: " + err; return
        }
        var side = (applyLeft && applyRight) ? "L+R" : (applyLeft ? "Left" : "Right")
        var deltaStr = factor >= 1.0 ? "+" + fmt(factor-1.0) : fmt(factor-1.0)
        statusMsg = "B: grow " + side + " delta " + deltaStr + " applied. OK=" + ok
                  + " fail=" + fail + " · saved=" + savedStates.length + "."
    }

    function setGrowValues(leftVal, rightVal, label) {
        var d = collectBeams()
        if (d.beams.length === 0) { statusMsg = "No beams found in selection."; return }
        var ok = 0, fail = 0
        try {
            curScore.startCmd()
            for (var i = 0; i < d.beams.length; i++) {
                var beam = d.beams[i]
                saveInitialStateIfNeeded(beam)
                try {
                    beam.growLeft  = leftVal
                    beam.growRight = rightVal
                    ok++
                } catch(e) { fail++ }
            }
            try { curScore.doLayout() } catch(eL) {}
            curScore.endCmd()
        } catch(err) {
            try { curScore.endCmd() } catch(ig) {}
            statusMsg = "Error: " + err; return
        }
        statusMsg = "B: " + label + " applied. L=" + fmt(leftVal) + " R=" + fmt(rightVal)
                  + ". OK=" + ok + " fail=" + fail + " · saved=" + savedStates.length + "."
    }

    function jointGrowBeams() {
        setGrowValues(growJointValue, growJointValue, "joint beams")
    }

    function factoryResetGrow() {
        setGrowValues(growDefaultLeft, growDefaultRight, "factory grow reset")
    }

    function resetGrow() {
        if (!savedStates || savedStates.length === 0) {
            statusMsg = "Nothing saved for Reset Grow. Use Joint beams for L/R=0 or Factory Reset for L/R=1.0."
            return
        }
        var ok = 0, fail = 0
        try {
            curScore.startCmd()
            for (var i = 0; i < savedStates.length; i++) {
                var s = savedStates[i]
                try {
                    if (!s || !s.beam) { fail++; continue }
                    s.beam.growLeft  = s.growL
                    s.beam.growRight = s.growR
                    ok++
                } catch(e) { fail++ }
            }
            try { curScore.doLayout() } catch(eL) {}
            curScore.endCmd()
        } catch(err) {
            try { curScore.endCmd() } catch(ig) {}
            statusMsg = "Error: " + err; return
        }
        statusMsg = "B: grow restored to initial state. OK=" + ok + " fail=" + fail + "."
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION C — SELECT BEAMS BY DIRECTION
    // ═══════════════════════════════════════════════════════════════════════

    function collectBeamAnchors() {
        var result = { beams: [], anchors: [], chordsTotal: 0, beamedChords: 0 }
        var sel = null
        try { sel = curScore.selection } catch(e) { return result }
        if (!sel) return result

        function beamIndex(beam) {
            for (var i = 0; i < result.beams.length; i++)
                if (sameElement(result.beams[i], beam)) return i
            return -1
        }

        function addAnchor(beam, anchor) {
            if (!beam) return
            var idx = beamIndex(beam)
            if (idx < 0) {
                result.beams.push(beam)
                result.anchors.push([])
                idx = result.beams.length - 1
            }
            if (!anchor) return
            for (var a = 0; a < result.anchors[idx].length; a++)
                if (sameElement(result.anchors[idx][a], anchor)) return
            result.anchors[idx].push(anchor)
        }

        function addFromChordRest(el) {
            if (!el) return
            result.chordsTotal++
            var beam = null
            try { beam = el.beam } catch(eB) {}
            if (!beam) return
            result.beamedChords++
            addAnchor(beam, el)
        }

        try {
            if (sel.isRange && sel.startSegment) {
                var seg     = sel.startSegment
                var endTick = sel.endSegment ? sel.endSegment.tick : 2147483647
                var stStart  = (typeof sel.startStaff !== "undefined" && sel.startStaff >= 0) ? sel.startStaff : 0
                // MuseScore 4 exposes endStaff as an exclusive upper bound.
                // Example: a range on staff n reports startStaff=n, endStaff=n+1.
                // Subtract 1 before using <= loops, otherwise operations leak to
                // the next lower staff.
                var stEndRaw = (typeof sel.endStaff !== "undefined" && sel.endStaff >= stStart) ? sel.endStaff : stStart
                var stEnd    = (stEndRaw > stStart) ? (stEndRaw - 1) : stStart
                var guard    = 0
                while (seg && seg.tick < endTick && guard < 50000) {
                    for (var st = stStart; st <= stEnd; st++) {
                        for (var v = 0; v < 4; v++) {
                            var el = null
                            try { el = seg.elementAt(st * 4 + v) } catch(e1) {}
                            if (isChord(el) || isRest(el)) addFromChordRest(el)
                        }
                    }
                    try { seg = seg.next } catch(eN) { break }
                    guard++
                }
            }
        } catch(eRange) {}

        try {
            var elems = sel.elements
            if (elems) {
                for (var k = 0; k < elems.length; k++) {
                    var e = elems[k]
                    if (!e) continue
                    if (isBeam(e)) { addAnchor(e, null); continue }
                    var ch = findChordFromElement(e)
                    if (ch) addFromChordRest(ch)
                    else if (isRest(e)) addFromChordRest(e)
                }
            }
        } catch(eElems) {}

        return result
    }

    function firstSelectableFromChordRest(el) {
        if (!el) return null
        if (isRest(el)) return el
        if (isChord(el)) {
            try {
                if (el.notes && el.notes.length > 0 && el.notes[0])
                    return el.notes[0]
            } catch(eNotes) {}
            return el
        }
        return el
    }

    function selectElementSafe(el, add) {
        if (!el) return false
        try { return curScore.selection.select(el, add) } catch(e) {}
        return false
    }

    function scheduleSelectBeamsByUp(upDirection) {
        root.pendingSelectUp = upDirection
        statusMsg = "C: preparing delayed selection filter for up=" + upDirection + "..."
        try { selectCommitTimer.restart() } catch(eTimer) { performSelectBeamsByUp(upDirection) }
    }

    function visualSelectionReset() {
        // MuseScore 4 can keep drawing the old range selection after the QML
        // selection object has already changed. Running the internal Escape
        // command after we have collected the targets commits/cancels the old
        // range visually, without losing our stored element references.
        var ok = false
        try { cmd("escape"); ok = true } catch(eEsc) {}
        try { curScore.selection.clear(); ok = true } catch(eClear) {}
        return ok
    }

    function selectionCommitNudge() {
        // Empty command transaction used only to make the score view/properties
        // panel notice the selection change immediately in MS4.
        var opened = false
        try { curScore.startCmd(); opened = true } catch(eStart) {}
        try { curScore.doLayout() } catch(eLayout) {}
        if (opened) {
            try { curScore.endCmd() } catch(eEnd) {}
        }
    }

    function elementIsSelected(el) {
        try { return !!el.selected } catch(e) {}
        return false
    }

    function trySelectBeamObject(beam, add) {
        if (!beam) return false

        // Public path: Selection.select(). On some builds it may reject Beam,
        // because the API officially supports only a limited set of element types.
        try {
            if (curScore.selection.select(beam, add)) return true
        } catch(e0) {}

        // Experimental fallback: try to set the read-only-looking selected flag.
        // Most builds will ignore/reject this, but it is harmless when unavailable.
        try {
            beam.selected = true
            if (elementIsSelected(beam)) return true
        } catch(e1) {}

        return false
    }

    function performSelectBeamsByUp(upDirection) {
        var d = collectBeamAnchors()
        if (d.beams.length === 0) {
            statusMsg = "C: no beams found in current selection."
            return
        }

        var targets = []
        var targetIdx = []
        var skippedBeams = 0
        for (var t = 0; t < d.beams.length; t++) {
            if (readUp(d.beams[t]) === upDirection) {
                targets.push(d.beams[t])
                targetIdx.push(t)
            } else {
                skippedBeams++
            }
        }

        if (targets.length === 0) {
            statusMsg = "C: no beams with up=" + upDirection + " found. collected="
                      + d.beams.length + " skipped=" + skippedBeams + ". Selection unchanged."
            return
        }

        var directBeamSelected = 0
        var directBeamFailed = 0
        var add = false
        var resetOk = visualSelectionReset()

        // First pass: try a real Beam-object list selection. This is the only
        // mode that can, in principle, allow dragging selected beams together
        // or showing Beam-specific Properties-panel controls. Most MS4 builds
        // reject Beam here; keep it as a test path in case a future build allows it.
        for (var b = 0; b < targets.length; b++) {
            if (trySelectBeamObject(targets[b], add)) {
                directBeamSelected++
                add = true
            } else {
                directBeamFailed++
            }
        }
        selectionCommitNudge()

        if (directBeamSelected > 0) {
            statusMsg = "C: selected Beam objects with up=" + upDirection
                      + ". target beams=" + targets.length
                      + " directBeam=" + directBeamSelected
                      + " directFail=" + directBeamFailed
                      + " reset=" + resetOk
                      + " skipped=" + skippedBeams + "."
            return
        }

        // Fallback pass: select note/rest anchors only if Beam-object selection is
        // completely rejected by this MuseScore build. visualSelectionReset() is
        // called again because the failed Beam-object selection can leave the old
        // range highlight stale on screen.
        var anchorSelected = 0
        var failed = 0
        add = false
        resetOk = visualSelectionReset()

        for (var ti = 0; ti < targetIdx.length; ti++) {
            var i = targetIdx[ti]
            var anchors = d.anchors[i]
            if (!anchors || anchors.length === 0) { failed++; continue }

            for (var a = 0; a < anchors.length; a++) {
                var selectable = firstSelectableFromChordRest(anchors[a])
                if (selectElementSafe(selectable, add)) {
                    anchorSelected++
                    add = true
                } else {
                    failed++
                }
            }
        }
        selectionCommitNudge()

        statusMsg = "C: MS4 rejected direct Beam-object selection; selected anchors instead. up="
                  + upDirection + " target beams=" + targets.length
                  + " anchorSelections=" + anchorSelected
                  + " fail=" + failed
                  + " reset=" + resetOk
                  + " skipped=" + skippedBeams + "."
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION D — ISOLATED STEMS
    // ═══════════════════════════════════════════════════════════════════════

    function parseStemDelta() {
        var f = parseNumber(stemFactorText, -1)
        if (!isFinite(f) || f <= 0) return -1
        return f
    }

    function containsElement(arr, el) {
        if (!el) return true
        for (var i = 0; i < arr.length; i++)
            if (sameElement(arr[i], el)) return true
        return false
    }

    function pushUnique(arr, el) {
        if (el && !containsElement(arr, el)) arr.push(el)
    }

    function isGraceChord(ch) {
        if (!ch) return false
        try { if (ch.isGrace) return true } catch(e0) {}
        try { if (ch.noteType && ch.noteType !== 0) return true } catch(e1) {}
        return false
    }

    function addGraceChordsFrom(chords, ch) {
        if (!ch || !includeGraceNotes) return
        try {
            var gs = ch.graceNotes
            if (!gs) return
            var n = Number(gs.length)
            if (!isFinite(n)) {
                try { n = Number(gs.count) } catch(eCount) { n = 0 }
            }
            if (!isFinite(n) || n <= 0) return
            for (var i = 0; i < n; i++) {
                var g = null
                try { g = gs[i] } catch(eI) { g = null }
                if (!g) { try { g = gs.get(i) } catch(eGet) { g = null } }
                if (g) {
                    pushUnique(chords, g)
                    addGraceChordsFrom(chords, g)
                }
            }
        } catch(e0) {}
    }

    function addChordForStemSelection(chords, ch) {
        if (!ch) return
        pushUnique(chords, ch)
        addGraceChordsFrom(chords, ch)
    }

    function selectedChordsForStems() {
        var chords = []
        var sel = null
        try { sel = curScore.selection } catch(e0) { sel = null }
        if (!sel) return chords

        try {
            if (sel.isRange && sel.startSegment) {
                var seg = sel.startSegment
                var endTick = sel.endSegment ? sel.endSegment.tick : 2147483647
                var startStaff  = (typeof sel.startStaff !== "undefined" && sel.startStaff >= 0) ? sel.startStaff : 0
                // MuseScore 4 exposes endStaff as an exclusive upper bound.
                // Example: a range on staff n reports startStaff=n, endStaff=n+1.
                // Subtract 1 before using <= loops, otherwise stem operations leak
                // to the next lower staff.
                var endStaffRaw = (typeof sel.endStaff !== "undefined" && sel.endStaff >= startStaff) ? sel.endStaff : startStaff
                var endStaff    = (endStaffRaw > startStaff) ? (endStaffRaw - 1) : startStaff
                var guard = 0
                while (seg && seg.tick < endTick && guard < 50000) {
                    for (var staff = startStaff; staff <= endStaff; staff++) {
                        for (var voice = 0; voice < 4; voice++) {
                            var track = staff * 4 + voice
                            var el = null
                            try { el = seg.elementAt(track) } catch(e1) { el = null }
                            if (isChord(el)) addChordForStemSelection(chords, el)
                        }
                    }
                    try { seg = seg.next } catch(eNext) { break }
                    guard++
                }
                return chords
            }
        } catch(eRange) {}

        try {
            var elems = sel.elements
            if (elems) {
                for (var i = 0; i < elems.length; i++) {
                    var ch = findChordFromElement(elems[i])
                    if (ch) addChordForStemSelection(chords, ch)
                }
            }
        } catch(eElems) {}

        if (chords.length === 0) {
            try {
                var cur = curScore.newCursor()
                cur.inputStateMode = Cursor.INPUT_STATE_SYNC_WITH_SCORE
                if (cur.element) {
                    var ch2 = findChordFromElement(cur.element)
                    if (ch2) addChordForStemSelection(chords, ch2)
                }
            } catch(eCur) {}
        }
        return chords
    }

    function analyzeStemSelection() {
        var chords = selectedChordsForStems()
        var isolated = []
        var beamed = 0
        var noStem = 0
        var graceSkipped = 0

        for (var i = 0; i < chords.length; i++) {
            var ch = chords[i]
            if (!includeGraceNotes && isGraceChord(ch)) { graceSkipped++; continue }

            var beam = null
            var stem = null
            try { beam = ch.beam } catch(eBeam) { beam = null }
            try { stem = ch.stem } catch(eStem) { stem = null }

            if (beam) beamed++
            else if (stem) pushUnique(isolated, stem)
            else noStem++
        }
        return { chords: chords, isolatedStems: isolated, beamedChords: beamed,
                 noStemChords: noStem, graceSkipped: graceSkipped }
    }

    function numberValue(v) {
        var n = Number(v)
        if (isFinite(n)) return n
        return 0
    }

    function stemLenValue(stem) {
        try { return numberValue(stem.userLen) } catch(e) { return 0 }
    }

    function stemBBoxHeight(stem) {
        try {
            var b = stem.bbox
            var h = Number(b.height)
            if (isFinite(h) && Math.abs(h) > 0.0001) return Math.abs(h)
        } catch(e0) {}
        try {
            var b2 = stem.bbox
            var h2 = Number(b2.height())
            if (isFinite(h2) && Math.abs(h2) > 0.0001) return Math.abs(h2)
        } catch(e1) {}
        return 0
    }

    function stemString(stem) {
        if (!stem) return "?"
        var s = fmt(stemLenValue(stem))
        var bh = stemBBoxHeight(stem)
        if (bh > 0) s += "/bbox " + fmt(bh)
        return s
    }

    function scaleStemByRelativeDelta(stem, relativeDelta) {
        if (!stem) return false

        // stem.userLen behaves as a manual adjustment relative to MuseScore's
        // default stem length. The user now supplies a decimal delta: 0.05 means
        // add/subtract 5% of the current visual stem length, depending on ▲/▼.
        var cur = stemLenValue(stem)
        var visualLen = stemBBoxHeight(stem)

        if (Math.abs(visualLen) < 0.0001) {
            visualLen = Math.abs(cur)
            if (Math.abs(visualLen) < 0.0001) visualLen = 3.5
        }

        var delta = visualLen * relativeDelta
        var nextLen = cur + delta
        try { stem.userLen = nextLen; return true } catch(e) {}
        return false
    }

    function resetStem(stem) {
        if (!stem) return false
        try { stem.userLen = 0; return true } catch(e) {}
        return false
    }

    function diagnoseStems() {
        var f = parseStemDelta()
        var a = analyzeStemSelection()
        var msg = "D: chords/notes=" + a.chords.length
                + "; isolated stems=" + a.isolatedStems.length
                + "; beamed ignored=" + a.beamedChords
                + "; no stem=" + a.noStemChords
                + "; grace skipped=" + a.graceSkipped
                + "; relative delta=" + (f > 0 ? f : "INVALID") + "."
        if (a.isolatedStems.length > 0) {
            msg += " Samples: "
            for (var k = 0; k < a.isolatedStems.length && k < sampleLimit; k++)
                msg += stemString(a.isolatedStems[k]) + " "
        }
        if (a.chords.length === 0) msg += " Select a range or specific notes/chords."
        statusMsg = msg
    }

    function applyStemDeltaArrow(direction) {
        var d = parseStemDelta()
        if (d <= 0) {
            statusMsg = "D: invalid stem delta. Use a decimal value like 0.05."
            return
        }
        applyStemRelativeDelta(direction >= 0 ? d : -d)
    }

    function applyStemRelativeDelta(relativeDelta) {
        if (!isFinite(relativeDelta) || Math.abs(relativeDelta) <= 0.0000001) {
            statusMsg = "D: invalid stem delta. Use a decimal value like 0.05."
            return
        }

        var a = analyzeStemSelection()
        if (a.chords.length === 0) {
            statusMsg = "D: no notes/chords found in selection."
            return
        }

        var changed = 0, skipped = 0, errMsg = ""
        try {
            curScore.startCmd()
            for (var j = 0; j < a.isolatedStems.length; j++) {
                try {
                    if (scaleStemByRelativeDelta(a.isolatedStems[j], relativeDelta)) changed++
                    else skipped++
                } catch(eStem) { errMsg += " stemErr=" + eStem; skipped++ }
            }
            try { curScore.doLayout() } catch(eLayout) {}
            curScore.endCmd()
        } catch(err) {
            try { curScore.endCmd() } catch(ignore) {}
            statusMsg = "D: error applying stem delta: " + err + errMsg
            return
        }

        var deltaStr = relativeDelta >= 0 ? "+" + fmt(relativeDelta) : fmt(relativeDelta)
        statusMsg = "D: stem relative delta " + deltaStr + " applied. isolated stems changed=" + changed
                  + "; skipped=" + skipped + "; beamed ignored=" + a.beamedChords
                  + "." + errMsg
    }

    function resetIsolatedStemsToDefault() {
        var a = analyzeStemSelection()
        if (a.chords.length === 0) {
            statusMsg = "D: no notes/chords found in selection."
            return
        }

        var reset = 0, skipped = 0, errMsg = ""
        try {
            curScore.startCmd()
            for (var j = 0; j < a.isolatedStems.length; j++) {
                try {
                    if (resetStem(a.isolatedStems[j])) reset++
                    else skipped++
                } catch(eStem) { errMsg += " stemErr=" + eStem; skipped++ }
            }
            try { curScore.doLayout() } catch(eLayout) {}
            curScore.endCmd()
        } catch(err) {
            try { curScore.endCmd() } catch(ignore) {}
            statusMsg = "D: error resetting stems: " + err + errMsg
            return
        }

        statusMsg = "D: reset applied. isolated stems reset to default=" + reset
                  + "; skipped=" + skipped + "; beamed ignored=" + a.beamedChords
                  + "." + errMsg
    }


    // ═══════════════════════════════════════════════════════════════════════
    // SECTION E — RESTORE ADVANCEDBEAMS SNAPSHOT / RESTORE
    // ═══════════════════════════════════════════════════════════════════════

    function isMeaningfulManualState(s) {
        if (!s) return false
        if (s.wasUserMod) return true
        if (s.wasNoSlope) return true
        if (Math.abs(Number(s.offX)) > 0.0001) return true
        if (Math.abs(Number(s.offY)) > 0.0001) return true
        if (s.bpOk && (Math.abs(Number(s.bpL)) > 0.0001 || Math.abs(Number(s.bpR)) > 0.0001)) return true
        if (Math.abs(Number(s.growL) - 1.0) > 0.0001) return true
        if (Math.abs(Number(s.growR) - 1.0) > 0.0001) return true
        return false
    }

    function readTick(el, fallbackTick) {
        var t = NaN
        try { t = Number(el.tick) } catch(e0) {}
        if (!isFinite(t)) t = Number(fallbackTick)
        return isFinite(t) ? t : 0
    }

    function readTrack(el, fallbackTrack) {
        var tr = NaN
        try { tr = Number(el.track) } catch(e0) {}
        if (!isFinite(tr)) tr = Number(fallbackTrack)
        return isFinite(tr) ? tr : 0
    }

    function collectBeamItems() {
        var result = { items: [], chordsTotal: 0, beamedChords: 0 }
        var sel = null
        try { sel = curScore.selection } catch(e) { return result }
        if (!sel) return result

        function findItemByBeamLocal(beam) {
            for (var i = 0; i < result.items.length; i++)
                if (sameElement(result.items[i].beam, beam)) return result.items[i]
            return null
        }

        function addBeamOnlyLocal(beam) {
            if (!beam) return null
            var item = findItemByBeamLocal(beam)
            if (item) return item
            item = {
                beam: beam,
                anchors: [],
                seen: {},
                staff: 0,
                voice: 0,
                firstTick: 0,
                lastTick: 0,
                tickCsv: "",
                strictKey: "",
                looseKey: "",
                orderKey: "",
                orderIndex: 0,
                up: readUp(beam)
            }
            result.items.push(item)
            return item
        }

        function addAnchorLocal(el, fallbackStaff, fallbackVoice, fallbackTick) {
            if (!el) return
            result.chordsTotal++
            var beam = null
            try { beam = el.beam } catch(eB) {}
            if (!beam) return
            result.beamedChords++

            var track = readTrack(el, fallbackStaff * 4 + fallbackVoice)
            var staff = Math.floor(track / 4)
            var voice = track - staff * 4
            if (!isFinite(staff) || staff < 0) staff = fallbackStaff
            if (!isFinite(voice) || voice < 0 || voice > 3) voice = fallbackVoice
            var tick = readTick(el, fallbackTick)
            var key = tick + ":" + track

            var item = addBeamOnlyLocal(beam)
            if (!item) return
            if (item.seen[key]) return
            item.seen[key] = true
            item.anchors.push({ tick: tick, track: track, staff: staff, voice: voice })
        }

        try {
            if (sel.isRange && sel.startSegment) {
                var seg     = sel.startSegment
                var endTick = sel.endSegment ? sel.endSegment.tick : 2147483647
                var stStart = (typeof sel.startStaff !== "undefined" && sel.startStaff >= 0) ? sel.startStaff : 0
                var stEndRaw = (typeof sel.endStaff !== "undefined" && sel.endStaff >= stStart) ? sel.endStaff : stStart
                var stEnd = (stEndRaw > stStart) ? (stEndRaw - 1) : stStart
                var guard = 0
                while (seg && seg.tick < endTick && guard < 50000) {
                    for (var st = stStart; st <= stEnd; st++) {
                        for (var v = 0; v < 4; v++) {
                            var el = null
                            try { el = seg.elementAt(st * 4 + v) } catch(e1) {}
                            if (isChord(el) || isRest(el)) addAnchorLocal(el, st, v, seg.tick)
                        }
                    }
                    try { seg = seg.next } catch(eN) { break }
                    guard++
                }
            }
        } catch(eRange) {}

        try {
            var elems = sel.elements
            if (elems) {
                for (var k = 0; k < elems.length; k++) {
                    var e = elems[k]
                    if (!e) continue
                    if (isBeam(e)) { addBeamOnlyLocal(e); continue }
                    if (isChord(e) || isRest(e)) {
                        var tr = readTrack(e, 0)
                        addAnchorLocal(e, Math.floor(tr / 4), tr % 4, readTick(e, 0))
                        continue
                    }
                    var ch = findChordFromElement(e)
                    if (ch) {
                        var tr2 = readTrack(ch, 0)
                        addAnchorLocal(ch, Math.floor(tr2 / 4), tr2 % 4, readTick(ch, 0))
                    }
                }
            }
        } catch(eElems) {}

        finalizeBeamItems(result)
        return result
    }

    function finalizeBeamItems(result) {
        var finalItems = []
        for (var i = 0; i < result.items.length; i++) {
            var item = result.items[i]
            if (!item || !item.anchors || item.anchors.length === 0) continue

            item.anchors.sort(function(a, b) {
                if (a.tick !== b.tick) return a.tick - b.tick
                return a.track - b.track
            })

            var first = item.anchors[0]
            var last  = item.anchors[item.anchors.length - 1]
            item.staff = first.staff
            item.voice = first.voice
            item.firstTick = first.tick
            item.lastTick  = last.tick
            item.up = readUp(item.beam)

            var ticks = []
            for (var j = 0; j < item.anchors.length; j++)
                ticks.push("" + item.anchors[j].tick)
            item.tickCsv = ticks.join(",")

            item.strictKey = item.staff + "|" + item.voice + "|" + item.tickCsv + "|" + item.anchors.length + "|" + (item.up ? "1" : "0")
            item.looseKey  = item.staff + "|" + item.voice + "|" + item.firstTick + "-" + item.lastTick + "|" + item.anchors.length
            item.orderKey  = item.staff + "|" + item.voice
            finalItems.push(item)
        }

        finalItems.sort(function(a, b) {
            if (a.staff !== b.staff) return a.staff - b.staff
            if (a.voice !== b.voice) return a.voice - b.voice
            if (a.firstTick !== b.firstTick) return a.firstTick - b.firstTick
            if (a.lastTick !== b.lastTick) return a.lastTick - b.lastTick
            return a.anchors.length - b.anchors.length
        })

        var counts = {}
        for (var q = 0; q < finalItems.length; q++) {
            var key = finalItems[q].orderKey
            var n = counts[key]
            if (!isFinite(n)) n = 0
            finalItems[q].orderIndex = n
            counts[key] = n + 1
        }

        result.items = finalItems
    }

    function makeSnapshotState(item, idx) {
        var beam = item.beam
        var off  = getOffset(beam)
        var bp   = readBeamPos(beam)
        var grow = readGrow(beam)
        return {
            idx: idx,
            strictKey: item.strictKey,
            looseKey: item.looseKey,
            orderKey: item.orderKey,
            orderIndex: item.orderIndex,
            staff: item.staff,
            voice: item.voice,
            firstTick: item.firstTick,
            lastTick: item.lastTick,
            tickCsv: item.tickCsv,
            count: item.anchors.length,
            up: item.up,
            offX: off.x,
            offY: off.y,
            bpOk: bp.ok,
            bpL: bp.l,
            bpR: bp.r,
            growL: grow.l,
            growR: grow.r,
            wasNoSlope: readBool(beam, "beamNoSlope"),
            wasUserMod: readBool(beam, "userModified")
        }
    }

    function saveSnapshot() {
        var d = collectBeamItems()
        if (d.items.length === 0) {
            statusMsg = "E: no beams found in selection. Select a range with beamed notes first."
            return
        }

        var states = []
        for (var i = 0; i < d.items.length; i++)
            states.push(makeSnapshotState(d.items[i], i))

        snapshotStates = states
        snapshotStamp = "" + new Date()

        var fileMsg = saveSnapshotToFile(false)
        statusMsg = "E: snapshot saved: " + states.length + " beams; anchors=" + d.beamedChords
                  + "; modified-like=" + countMeaningfulStates(states)
                  + ". " + fileMsg
    }

    function countMeaningfulStates(states) {
        var n = 0
        for (var i = 0; i < states.length; i++)
            if (isMeaningfulManualState(states[i])) n++
        return n
    }

    function clearSnapshot() {
        snapshotStates = []
        snapshotStamp = ""
        statusMsg = "E: snapshot memory cleared. The file, if any, was not deleted."
    }

    function restoreSnapshot() {
        if (!snapshotStates || snapshotStates.length === 0) {
            if (!loadSnapshotFromFile(false)) {
                statusMsg = "E: no snapshot in memory and no readable snapshot file. Save snapshot first."
                return
            }
        }

        var d = collectBeamItems()
        if (d.items.length === 0) {
            statusMsg = "E: no current beams found in selection. Select the corresponding range before restoring."
            return
        }

        var used = {}
        var restored = 0, missing = 0, fail = 0
        var strict = 0, loose = 0, order = 0

        try {
            curScore.startCmd()
            for (var i = 0; i < snapshotStates.length; i++) {
                var s = snapshotStates[i]
                var m = findMatchForState(s, d.items, used)
                if (!m || !m.item) { missing++; continue }

                used[m.index] = true
                if (applyStateToBeam(m.item.beam, s)) {
                    restored++
                    if (m.mode === "strict") strict++
                    else if (m.mode === "loose") loose++
                    else order++
                } else {
                    fail++
                }
            }
            try { curScore.doLayout() } catch(eL) {}
            curScore.endCmd()
        } catch(err) {
            try { curScore.endCmd() } catch(ig) {}
            statusMsg = "E: restore error: " + err
            return
        }

        statusMsg = "E: restore done: restored=" + restored
                  + " strict=" + strict + " loose=" + loose + " order=" + order
                  + " missing=" + missing + " fail=" + fail
                  + "; current beams=" + d.items.length + "."
    }

    function findMatchForState(s, items, used) {
        var m = findUnusedByProperty(items, used, "strictKey", s.strictKey)
        if (m) return { item: m.item, index: m.index, mode: "strict" }

        m = findUnusedByProperty(items, used, "looseKey", s.looseKey)
        if (m) return { item: m.item, index: m.index, mode: "loose" }

        for (var i = 0; i < items.length; i++) {
            if (used[i]) continue
            if (items[i].orderKey === s.orderKey && Number(items[i].orderIndex) === Number(s.orderIndex))
                return { item: items[i], index: i, mode: "order" }
        }
        return null
    }

    function findUnusedByProperty(items, used, prop, value) {
        if (!value || value === "") return null
        for (var i = 0; i < items.length; i++) {
            if (used[i]) continue
            if (items[i][prop] === value) return { item: items[i], index: i }
        }
        return null
    }

    function applyStateToBeam(beam, s) {
        if (!beam || !s) return false
        var ok = false
        var needsManual = isMeaningfulManualState(s)

        try { primeManualBeam(beam); ok = true } catch(ePrime) {}
        try { if (needsManual) ensureUserModified(beam); ok = true } catch(eUM) {}

        if (s.bpOk) {
            try { writeBeamPos(beam, Number(s.bpL), Number(s.bpR)); ok = true } catch(eBP) {}
        }

        try {
            var offX = Number(s.offX)
            var offY = Number(s.offY)
            if (!isFinite(offX)) offX = 0
            if (!isFinite(offY)) offY = 0
            beam.offset = Qt.point(offX, offY)
            ok = true
        } catch(eOff) {}

        try {
            var gl = Number(s.growL)
            var gr = Number(s.growR)
            if (isFinite(gl)) beam.growLeft = gl
            if (isFinite(gr)) beam.growRight = gr
            ok = true
        } catch(eGrow) {}

        try { beam.beamNoSlope = !!s.wasNoSlope; ok = true } catch(eSlope) {}

        try {
            beam.userModified = needsManual ? true : !!s.wasUserMod
            ok = true
        } catch(eFinalUM) {}

        return ok
    }

    function diagnoseSnapshotSelection() {
        var d = collectBeamItems()
        var snapCount = snapshotStates ? snapshotStates.length : 0
        var modified = 0, noSlope = 0, readableBp = 0
        for (var i = 0; i < d.items.length; i++) {
            var b = d.items[i].beam
            if (readBool(b, "userModified")) modified++
            if (readBool(b, "beamNoSlope")) noSlope++
            if (readBeamPos(b).ok) readableBp++
        }

        var matchText = ""
        if (snapCount > 0) {
            var counts = countPotentialMatches(d.items)
            matchText = "; potential strict=" + counts.strict + " loose=" + counts.loose + " order=" + counts.order + " missing=" + counts.missing
        }

        statusMsg = "E: selection beams=" + d.items.length
                  + "; anchors=" + d.beamedChords
                  + "; userModified=" + modified
                  + "; beamNoSlope=" + noSlope
                  + "; readable beamPos=" + readableBp
                  + "; snapshot=" + snapCount + matchText + "."
    }

    function countPotentialMatches(items) {
        var used = {}
        var out = { strict: 0, loose: 0, order: 0, missing: 0 }
        for (var i = 0; i < snapshotStates.length; i++) {
            var m = findMatchForState(snapshotStates[i], items, used)
            if (!m || !m.item) { out.missing++; continue }
            used[m.index] = true
            if (m.mode === "strict") out.strict++
            else if (m.mode === "loose") out.loose++
            else out.order++
        }
        return out
    }

    function snapshotSummaryText() {
        var n = snapshotStates ? snapshotStates.length : 0
        if (n === 0) return "No E snapshot loaded. Workflow: Save snap → change time signature/reset beams → select corresponding range → Restore snap."
        var path = snapshotFilePath && snapshotFilePath !== "" ? (" · file: " + snapshotFilePath) : ""
        return "E snapshot in memory: " + n + " beams · " + snapshotStamp + path
    }

    function snapshotFileCandidates() {
        var out = []
        try {
            if (root.filePath && root.filePath !== "")
                out.push(normalizePath(root.filePath) + "/RestoreAdvancedBeams_snapshot.json")
        } catch(e0) {}
        try {
            var h = normalizePath(snapshotFile.homePath())
            if (h && h !== "") {
                out.push(h + "/RestoreAdvancedBeams_snapshot.json")
                out.push(h + "/Documents/RestoreAdvancedBeams_snapshot.json")
            }
        } catch(e1) {}
        try {
            var t = normalizePath(snapshotFile.tempPath())
            if (t && t !== "")
                out.push(t + "/RestoreAdvancedBeams_snapshot.json")
        } catch(e2) {}
        return out
    }

    function snapshotPackage() {
        return {
            plugin: "Advanced Beams / Restore AdvancedBeams",
            version: "2.5-section-e-0.1",
            stamp: snapshotStamp,
            states: snapshotStates
        }
    }

    function saveSnapshotToFile(verbose) {
        if (!snapshotStates || snapshotStates.length === 0) {
            if (verbose) statusMsg = "E: no snapshot to save."
            return "No snapshot to save to file."
        }
        if (snapshotStamp === "") snapshotStamp = "" + new Date()

        var data = ""
        try {
            data = JSON.stringify(snapshotPackage())
        } catch(eJson) {
            return "Memory OK, but JSON export failed: " + eJson
        }

        var candidates = snapshotFileCandidates()
        var lastErr = ""
        for (var i = 0; i < candidates.length; i++) {
            try {
                fileIoLastError = ""
                snapshotFile.source = candidates[i]
                if (snapshotFile.write(data)) {
                    snapshotFilePath = candidates[i]
                    if (verbose) statusMsg = "E: snapshot saved to file: " + candidates[i]
                    return "File saved: " + candidates[i]
                }
                if (fileIoLastError && fileIoLastError !== "") lastErr = fileIoLastError
            } catch(e) {
                lastErr = "" + e
            }
        }
        return "Memory OK; file write failed" + (lastErr !== "" ? ": " + lastErr : ".")
    }

    function ensureSnapshotFileSourceForRead() {
        var candidates = snapshotFileCandidates()
        for (var i = 0; i < candidates.length; i++) {
            try {
                snapshotFile.source = candidates[i]
                if (snapshotFile.exists()) {
                    snapshotFilePath = candidates[i]
                    return true
                }
            } catch(e) {}
        }
        return false
    }

    function loadSnapshotFromFile(verbose) {
        try {
            if (!ensureSnapshotFileSourceForRead()) {
                if (verbose) statusMsg = "E: no snapshot file found in plugin/home/Documents/temp paths."
                return false
            }
            var data = snapshotFile.read()
            if (!data || data === "") {
                if (verbose) statusMsg = "E: snapshot file exists but is empty."
                return false
            }
            var pkg = JSON.parse(data)
            var states = null
            if (pkg && pkg.states) states = pkg.states
            else if (pkg && pkg.length) states = pkg
            if (!states || states.length === 0) {
                if (verbose) statusMsg = "E: snapshot file has no saved beam states."
                return false
            }
            snapshotStates = states
            snapshotStamp = (pkg && pkg.stamp) ? pkg.stamp : "loaded from file"
            if (verbose) statusMsg = "E: snapshot loaded from file: " + states.length + " beams. File: " + snapshotFilePath
            return true
        } catch(e) {
            if (verbose) statusMsg = "E: could not load snapshot file: " + e
            return false
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // DIAGNOSE
    // ═══════════════════════════════════════════════════════════════════════

    function diagnose() {
        var d = collectBeams()
        var manual = 0, automatic = 0, sample = ""
        for (var i = 0; i < d.beams.length; i++) {
            var beam = d.beams[i]
            var man  = isManualBeam(beam)
            if (man) manual++; else automatic++
            if (i < sampleLimit) {
                var off  = getOffset(beam)
                var grow = readGrow(beam)
                sample += " #" + (i+1)
                        + (man ? " M" : " A")
                        + " up=" + readUp(beam)
                        + " bp=(" + fmt(readBeamPos(beam).l) + "," + fmt(readBeamPos(beam).r) + ")"
                        + " offY=" + fmt(off.y)
                        + " umod=" + readBool(beam,"userModified")
                        + " noSlope=" + readBool(beam,"beamNoSlope")
                        + " gL=" + fmt(grow.l)
                        + " gR=" + fmt(grow.r)
            }
        }
        statusMsg = "Range: " + d.chordsTotal + " elements · "
                  + d.beamedChords + " beamed · "
                  + d.beams.length + " unique beams · M=" + manual
                  + " A=" + automatic
                  + " · saved=" + savedStates.length
                  + "." + sample
    }

    // ═══════════════════════════════════════════════════════════════════════
    // RESET ALL
    // ═══════════════════════════════════════════════════════════════════════

    function resetAll() {
        if (!savedStates || savedStates.length === 0) {
            statusMsg = "Nothing saved for reset. State is captured on first apply."
            return
        }
        var ok = 0, fail = 0
        try {
            curScore.startCmd()
            for (var i = 0; i < savedStates.length; i++) {
                var s = savedStates[i]
                try {
                    if (!s || !s.beam) { fail++; continue }
                    try { restoreBeamPosFromState(s) } catch(eBP) {}
                    s.beam.offset = Qt.point(s.offX, s.offY)
                    try { s.beam.userModified = s.wasUserMod } catch(e1) {}
                    try { s.beam.beamNoSlope  = s.wasNoSlope } catch(e2) {}
                    try { s.beam.growLeft     = s.growL      } catch(e3) {}
                    try { s.beam.growRight    = s.growR      } catch(e4) {}
                    ok++
                } catch(e0) { fail++ }
            }
            try { curScore.doLayout() } catch(eL) {}
            curScore.endCmd()
        } catch(err) {
            try { curScore.endCmd() } catch(ig) {}
            statusMsg = "Error resetting: " + err; return
        }
        savedStates = []
        statusMsg = "Reset All complete: " + ok + " beams restored · failures: " + fail + "."
    }
}
