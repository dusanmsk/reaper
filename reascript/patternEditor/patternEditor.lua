--[[
Keys:
f2 - decrease grid size
f3 - increase grid size
f4 - turn on loud mode
f5 - refresh pattern (from reaper item, will be refreshed automatically when enabling edit mode)
f6 - decrease step size
f7 - increase step size
space - toggle play
esc - toggle edit mode

TODO:
    - zvazit ci je sposob nastavovania dlzky not sposobom "ton hra az po znak ===" spravny a ci by to nemohlo byt skor naopak,
      tzn. jeden riadok povedzme "A-5" by bola nota dlha gridsize a pokial by mala hrat dlhsie tak pouzit nejaku specialnu klavesu
      na jej predlzenie (napr. \). A zobrazit to ako "-|-" napr. alebo " | "

    - loud mode bude mat 3 rezimy:
        - off
        - single track
        - multiple track (prehra vsetky noty zo vsetkych trackov)

]]

--[[
30 ppq = 1/128
 ]]

gui = {}

gui.fontsize = 20
gui.trackColumns = 4
gui.numOfTracks = 8
gui.displayLines = 32
gui.lineColOffset = 5
gui.lineColWidth = 30
gui.trackSize = 110
gui.patternStartLine = 3
gui.patternVisibleLines = 0
gui.loudMode = false
gui.stepSize = 1
gui.gridSize = 16
gui.editMode = false

gui.update = function(patternLength)
    gui.displayLines = math.floor(gfx.h / gui.fontsize) - 1
    gui.patternVisibleLines = gui.displayLines - gui.patternStartLine
    if gui.patternVisibleLines > patternLength then gui.patternVisibleLines = patternLength end
end

gui.toOnOffString = function(value)
    return value == false and 'off' or 'on'
end

gui.patternLine2y = function(patternLine)
    return line2y(patternLine + gui.patternStartLine)
end

gui.getNumOfVisiblePatternLines = function()
    local numOfLines = math.floor(pattern.steps * (gui.gridSize / 128))
    if numOfLines > gui.patternVisibleLines then numOfLines = gui.patternVisibleLines end
    return numOfLines
end

cursor = {}
cursor.track = 0
cursor.column = 0
cursor.line = 0
cursor.down = function()
    for i = 1, gui.stepSize, 1 do
        cursor.line = cursor.line + 1
        if cursor.line > gui.getNumOfVisiblePatternLines() - 1 then
            cursor.line = gui.getNumOfVisiblePatternLines() - 1;
            pattern.scrollDown();
        end
    end
    -- todo
end
cursor.up = function()
    -- todo
    for i = 1, gui.stepSize, 1 do
        cursor.line = cursor.line - 1
        if cursor.line < 0 then
            cursor.line = 0;
            pattern.scrollUp();
        end
    end
end
cursor.right = function()
    cursor.column = cursor.column + 1
    if cursor.column > gui.trackColumns - 1 then cursor.track = cursor.track + 1; cursor.column = 0; end
    if cursor.track > gui.numOfTracks - 1 then cursor.track = 0 end
end
cursor.left = function()
    cursor.column = cursor.column - 1
    if cursor.column < 0 then cursor.track = cursor.track - 1; cursor.column = gui.trackColumns - 1; end
    if cursor.track < 0 then cursor.track = gui.numOfTracks - 1; cursor.column = gui.trackColumns - 1; end
end
cursor.pageDown = function()
    for i = 1, gui.getNumOfVisiblePatternLines(), 1 do
        cursor.down()
    end
end
cursor.pageUp = function()
    for i = 1, gui.getNumOfVisiblePatternLines(), 1 do
        cursor.up()
    end
end

-- convert gui pattern line to pattern index
-- handles scrolling and todo grid
cursor.toPatternIndex = function(line)
    return math.floor((line) * 128 / gui.gridSize)
end

cursor.toGuiLine = function(patternIndex)
    return math.floor(patternIndex / 128 * gui.gridSize)
end


MIDI_CLIP_SAVE_UPDATE_TIME = 0.5
MIDI_CLIP_LOAD_UPDATE_TIME = 2



NOTE_OFF = -1

keycodes = {}
keycodes.rightArrow = 1919379572
keycodes.leftArrow = 1818584692
keycodes.upArrow = 30064
keycodes.downArrow = 1685026670
keycodes.octaveDown = 47
keycodes.octaveUp = 42
keycodes.space = 32
keycodes.pageUp = 1885828464
keycodes.pageDown = 1885824110
keycodes.homeKey = 1752132965
keycodes.endKey = 6647396
keycodes.deleteKey = 6579564
keycodes.insertKey = 6909555
keycodes.escKey = 27
keycodes.enter = 13
keycodes.f2 = 26162
keycodes.f3 = 26163
keycodes.f4 = 26164
keycodes.f5 = 26165
keycodes.f6 = 26166
keycodes.f7 = 26167
keycodes.f8 = 26168

keycodes.space = 32

global = {}
gui.octave = 4

function dbg(m)
    return reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

function trace(m)
    dbg(m .. debug.traceback())
end

function err(m)
    msg = "Error" .. m
    dbg(msg)
end

pattern = {}
pattern.data = {}
pattern.tracks = {}
pattern.steps = 0
cursor.patternOffsetLines = 0

pattern.scrollUp = function()
    cursor.patternOffsetLines = cursor.patternOffsetLines - 1
    if cursor.patternOffsetLines < 0 then cursor.patternOffsetLines = 0; end
end
pattern.scrollDown = function()
    cursor.patternOffsetLines = cursor.patternOffsetLines + 1
    local patternGuiLines = cursor.toGuiLine(pattern.steps)
    if cursor.patternOffsetLines > patternGuiLines - gui.getNumOfVisiblePatternLines() then
        cursor.patternOffsetLines = patternGuiLines - gui.getNumOfVisiblePatternLines();
    end
end

pattern.init = function(steps)
    pattern.steps = steps
    for i = 0, steps - 1, 1 do
        pattern.data[i] = {}
        for trackNo = 0, gui.numOfTracks, 1 do
            pattern.data[i][trackNo] = nil
        end
    end
end

pattern.getRecord = function(position, track)
    return pattern.data[position][track]
end

pattern.setRecord = function(position, track, rec)
    if position > pattern.steps - 1 then
        err("Invalid position")
        return nil
    end
    pattern.data[position][track] = rec
end



WHITE = { r = 0.8, g = 0.8, b = 0.8 }
WHITE_BRIGHT = { r = 1.0, g = 1.0, b = 1.0 }
YELLOW = { r = 1.0, g = 1.0, b = 0.5 }
GREEN = { r = 0.0, g = 1.0, b = 0.0 }
BLACK = { r = 0.0, g = 0.0, b = 0.0 }
function setColor(color)
    gfx.set(color.r, color.g, color.b)
end


function linesToBeats(lines)
    if lines == 0 then return 0 end
    return lines / gui.gridSize
end


function init()
    gfx.init("Pattern editor", 800, 800, 0)
    gfx.setfont(1, "Monospace", gui.fontsize)
    gfx.clear = 55
    -- gfx.dock(1) -- todo store/restore

    pattern.tracks = {}
    for i = 0, gui.numOfTracks, 1 do
        pattern.tracks[i] = {}
    end

    cursor.track = 0
    cursor.column = 0
    cursor.line = 0
    cursor.patternOffsetLines = 0

    pattern.editor = reaper.MIDIEditor_GetActive()
    if pattern.editor then
        pattern.take = reaper.MIDIEditor_GetTake(pattern.editor)
        pattern.item = reaper.GetMediaItemTake_Item(pattern.take)
        itemLengthSec = reaper.GetMediaItemInfo_Value(pattern.item, 'D_LENGTH')
        retval, measuresOutOptional, cmlOutOptional, fullbeatsOutOptional, cdenomOutOptional = reaper.TimeMap2_timeToBeats(0, itemLengthSec)
        pattern.init(beatsToPatternSteps(fullbeatsOutOptional))
        loadMidiClip()
        -- todo calculate grid size from note length
        update()
    end
end

function beatsToPatternSteps(beats)
    -- 1 beat = 32 1/128 notes
    return math.floor(beats * 32)
end

function patternStepsToBeats(steps)
    -- 1 beat = 32 1/128 notes
    return steps / 32
end


noteStrings = { "C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-" }
function noteToString(pitch)
    if pitch == nil then return nil end
    if pitch == NOTE_OFF then return "===" end
    octave = math.floor(pitch / 12)
    n = pitch - 12 * octave
    note = noteStrings[n + 1]
    return string.format("%s%s", note, octave)
end

function isSelected(line, track, column)
    return cursor.line == line and cursor.column == column and cursor.track == track
end

function cellValue(fmt, value, nilValue)
    if value == nil then return nilValue; end
    return string.format(fmt, value);
end

function line2y(line)
    return line * gui.fontsize
end


trackColumnOffset = {}
trackColumnOffset[0] = 0
trackColumnOffset[1] = 35
trackColumnOffset[2] = 60
trackColumnOffset[3] = 80
trackColumnOffset[4] = 100
trackColumnOffset[5] = 200

function trackCellX(trackNo, column)
    local x = gui.lineColOffset + gui.lineColWidth
    x = x + gui.trackSize * trackNo
    return x + trackColumnOffset[column]
end

function drawCell(trackNo, line, column, value)
    local x = trackCellX(trackNo, column)
    local y = gui.patternLine2y(line)
    if isSelected(line, trackNo, column) then
        local w, h = gfx.measurestr(value)
        setColor(GREEN)
        gfx.rect(x, y, w, h, 1)
        setColor(BLACK)
        gfx.x = x; gfx.y = y
        gfx.printf(value)
    else
        setColorByLine(line + cursor.patternOffsetLines)
        gfx.x = x; gfx.y = y
        gfx.printf(value)
    end
end


function drawTrackEntry(rec, line, trackNo)
    if rec ~= nil then
        drawCell(trackNo, line, 0, cellValue("%s", noteToString(rec.pitch), ' ---'))
        drawCell(trackNo, line, 1, cellValue("%02x", rec.velocity, '--'))
        drawCell(trackNo, line, 2, cellValue("%02x", rec.f1, '--'))
        drawCell(trackNo, line, 3, cellValue("%02x", rec.f2, '--'))
        drawCell(trackNo, line, 4, '|')
    else
        drawCell(trackNo, line, 0, " ---")
        drawCell(trackNo, line, 1, "--")
        drawCell(trackNo, line, 2, "--")
        drawCell(trackNo, line, 3, "--")
        drawCell(trackNo, line, 4, '|')
    end
end

-- draw specified track
function drawTrack(trackNo)
    for line = 0, gui.patternVisibleLines - 1, 1 do
        trackData = pattern.tracks[trackNo]
        -- todo grid
        rec = trackData[line + cursor.patternOffsetLines]
        drawTrackEntry(rec, trackNo, line)
    end
end

function deleteRecord(recordIndex, trackNo)
    pattern.setRecord(recordIndex, trackNo, nil)
    emitEdited()
end


function getCurrentOctave()
    return gui.octave
end

function toPitch(pitch)
    if (pitch == NOTE_OFF) then return NOTE_OFF end
    -- C-1 == 0, every octave +12
    return pitch + 12 * (getCurrentOctave() + 1)
end

currentToneTimestamps = {}
function generateTone(pitch)
    if pitch ~= NOTE_OFF then
        reaper.StuffMIDIMessage(0, 0x90, pitch, 0x60)
        currentToneTimestamps[pitch] = os.clock()
    end
end

function muteTone(pitch)
    reaper.StuffMIDIMessage(0, 0x80, pitch, 0)
    currentToneTimestamps[pitch] = nil
end

function muteTones(imediately)
    for k, v in pairs(currentToneTimestamps) do
        if os.clock() - v > 1 or imediately then
            muteTone(k)
        end
    end
end

function changeOctave(how)
    gui.octave = gui.octave + how
    if gui.octave < 0 then gui.octave = 0 end
    if gui.octave > 6 then gui.octave = 6 end
end

lastPatternEditTime = 0
function emitEdited()
    lastPatternEditTime = os.clock()
end

function toggleEditMode()
    if gui.editMode then
        -- undo nefunguje ako som cakal. Pokial sa midi item updatlo automaticky este pred zavolanim tohoto kodu,
        -- nevytvori sa ziaden undo point (asi lebo sa nezmenil item). Ked sa toto zavola este pred zapisom patternu, tak sa vytvori
        --reaper.Undo_BeginBlock()
        saveMidiClip()
        --reaper.Undo_OnStateChangeEx("MIDI clip updated by pattern editor", -1, -1)
        --reaper.Undo_OnStateChange_Item(0, "TODO1", pattern.item)
        --reaper.Undo_EndBlock("TODO2", 4)
    else
        refreshPattern()
    end
    gui.editMode = not gui.editMode
end

function refreshPattern()
    loadMidiClip()
    update()
end

function notePressed(key)
    pitch = nil
    if isKey(key, 'z') then pitch = 0 end
    if isKey(key, 's') then pitch = 1 end
    if isKey(key, 'x') then pitch = 2 end
    if isKey(key, 'd') then pitch = 3 end
    if isKey(key, 'c') then pitch = 4 end
    if isKey(key, 'v') then pitch = 5 end
    if isKey(key, 'g') then pitch = 6 end
    if isKey(key, 'b') then pitch = 7 end
    if isKey(key, 'h') then pitch = 8 end
    if isKey(key, 'n') then pitch = 9 end
    if isKey(key, 'j') then pitch = 10 end
    if isKey(key, 'm') then pitch = 11 end
    if isKey(key, 'q') then pitch = 12 end
    if isKey(key, '2') then pitch = 13 end
    if isKey(key, 'w') then pitch = 14 end
    if isKey(key, '3') then pitch = 15 end
    if isKey(key, 'e') then pitch = 16 end
    if isKey(key, 'r') then pitch = 17 end
    if isKey(key, '5') then pitch = 18 end
    if isKey(key, 't') then pitch = 19 end
    if isKey(key, '6') then pitch = 20 end
    if isKey(key, 'y') then pitch = 21 end
    if isKey(key, '7') then pitch = 22 end
    if isKey(key, 'u') then pitch = 23 end
    if isKey(key, 'i') then pitch = 24 end
    if isKey(key, '9') then pitch = 25 end
    if isKey(key, 'o') then pitch = 26 end
    if isKey(key, '0') then pitch = 27 end

    if isKey(key, '`') then pitch = NOTE_OFF end

    if pitch ~= nil then
        if gui.editMode then
            local rec = getNoteAtCursor()
            if rec == nil then
                rec = {}
                if rec.pitch ~= NOTE_OFF then
                    rec.velocity = 32 -- TODO default velocity from gui
                end
            end
            rec.pitch = toPitch(pitch)
            insertNoteAtCursor(rec)
            cursor.down()
        end
        generateTone(toPitch(pitch))
    end
end

function getNoteAtCursor()
    patternIndex = cursor.toPatternIndex(cursor.line + cursor.patternOffsetLines)
    return pattern.getRecord(patternIndex, cursor.track)
end


function insertNoteAtCursor(rec)
    patternIndex = cursor.toPatternIndex(cursor.line + cursor.patternOffsetLines)
    pattern.setRecord(patternIndex, cursor.track, rec)
    emitEdited()
end

function deleteUnderCursor()
    if not gui.editMode == true then return end
    -- todo do not delete whole line, but only what is under cursor
    deleteRecord(cursor.toPatternIndex(cursor.line + cursor.patternOffsetLines), cursor.track)
    processKey(keycodes.downArrow)
end


function isKey(key, ch)
    return string.byte(ch) == key
end

-- grid size to command id of sws "Grid: set to x" commands
gridSizeToSWSAction = {}
gridSizeToSWSAction[128] = 41019
gridSizeToSWSAction[64] = 41020
gridSizeToSWSAction[32] = 40190
gridSizeToSWSAction[16] = 40192
gridSizeToSWSAction[8] = 40197
gridSizeToSWSAction[4] = 40201
gridSizeToSWSAction[2] = 40203
gridSizeToSWSAction[1] = 40204

function decrementGrid()
    gui.gridSize = gui.gridSize * 2
    if gui.gridSize > 128 then gui.gridSize = 128 end
    cursor.line = 0
    saveMidiClip()
end

function incrementGrid()
    if not isPossibleToIncrementGrid() then return end
    gui.gridSize = gui.gridSize / 2
    if gui.gridSize < 1 then gui.gridSize = 1 end
    if gui.getNumOfVisiblePatternLines() < 4 then gui.gridSize = gui.gridSize * 2; end
    cursor.line = 0
    savePatternSysexProperties()
    saveMidiClip()
end

function updateEditorGrid()
    local cmdId = gridSizeToSWSAction[gui.gridSize]
    if cmdId then reaper.MIDIEditor_OnCommand(pattern.editor, cmdId) end
end

function incrementStepSize()
    gui.stepSize = gui.stepSize + 1
    if gui.stepSize > pattern.steps then gui.stepSize = pattern.steps end
end

function decrementStepSize()
    gui.stepSize = gui.stepSize - 1
    if gui.stepSize < 0 then gui.stepSize = 0 end
end

function playSelectedLine()
    if gui.loudMode then
        local patternIndex = cursor.toPatternIndex(cursor.line + cursor.patternOffsetLines)
        local rec = pattern.getRecord(patternIndex, cursor.track)
        if rec ~= nil and rec.pitch ~= nil then
            generateTone(rec.pitch)
        end
    end
end

function processKeyboard()
    key = gfx.getchar()
    if key ~= 0 then
        muteTones(true)
    end
    return processKey(key)
end

function processKey(key)
    if key ~= 0 then
        if key == keycodes.downArrow then cursor.down(); playSelectedLine(); end
        if key == keycodes.upArrow then cursor.up(); playSelectedLine(); end
        if key == keycodes.rightArrow then cursor.right() end
        if key == keycodes.leftArrow then cursor.left() end
        if key == keycodes.octaveUp then changeOctave(1) end
        if key == keycodes.octaveDown then changeOctave(-1) end
        if key == keycodes.deleteKey then deleteUnderCursor() end
        if key == keycodes.homeKey then cursor.patternOffsetLines = 0 end
        if key == keycodes.endKey then cursor.patternOffsetLines = pattern.steps - gui.patternVisibleLines end
        -- todo checks inside patter class
        if key == keycodes.pageDown then cursor.pageDown() end
        if key == keycodes.pageUp then cursor.pageUp() end
        if key == keycodes.f2 then decrementGrid() end
        if key == keycodes.f3 then incrementGrid() end
        if key == keycodes.f4 then gui.loudMode = not gui.loudMode; playSelectedLine(); end
        if key == keycodes.f5 then refreshPattern() end
        if key == keycodes.f6 then decrementStepSize() end
        if key == keycodes.f7 then incrementStepSize() end
        if key == keycodes.space then reaperTogglePlay() end
        if key == keycodes.escKey then toggleEditMode() end

        notePressed(key)
        return true
    end
    return false
end

function reaperTogglePlay()
    -- todo seek cursor
    local patternIndex = cursor.toPatternIndex(cursor.line + cursor.patternOffsetLines)
    local beats = patternStepsToBeats(patternIndex)
    local patternItemPositionSec = reaper.TimeMap2_beatsToTime(0, beats, 0)
    local itemPositionSec = reaper.GetMediaItemInfo_Value(pattern.item, "D_POSITION")
    local globalPositionSec = itemPositionSec + patternItemPositionSec
    reaper.Main_OnCommand(40044, 0)
    reaper.SetEditCurPos(globalPositionSec, true, true)
end

function patternPosition2ppq(position)
    -- 1/128 note = 30 ppq
    return math.floor(position * 30)
end

function ppq2patternPosition(position)
    -- 1/128 note = 30 ppq
    return math.floor(position / 30)
end


function ppq2line(ppq)
    -- todo grid size
    return ppq / 480 * gui.gridSize / 2
end

function round(value)
    floor = math.floor(value)
    tmp1 = value % floor
    if tmp1 >= 0.5 then
        return floor + 1
    end
    return floor
end


function getTakeLengthPPQ(take)
    item = reaper.GetMediaItemTake_Item(take)
    len_sec = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    return reaper.MIDI_GetPPQPosFromProjTime(take, len_sec)
end

-- return note length (in pattern positions)
function getPatternNoteLength(patternPosition, trackNo)
    -- iterate over track, note length is until (new note or note_off or pattern end) occure
    for i = patternPosition + 1, pattern.steps - 1, 1 do
        local rec = pattern.getRecord(i, trackNo)
        if (rec ~= nil and rec.pitch ~= nil) then
            return i - patternPosition
        end
    end
    return pattern.steps - patternPosition
end


function isPossibleToIncrementGrid()
    -- find odd records then false
    for line = 1, cursor.toGuiLine(pattern.steps) - 1, 2 do
        local patternIndex = cursor.toPatternIndex(line)
        for track = 0, gui.numOfTracks, 1 do
            local rec = pattern.getRecord(patternIndex, track)
            if rec then return false end
        end
    end
    return true
end

-- loads data from midi clip
function loadMidiClip()

    loadPatternSysexProperties()
    -- todo unquantize original midi clip by reaper action before read
    reaper.MIDIEditor_OnCommand(pattern.editor, 40003) -- select all
    reaper.MIDIEditor_OnCommand(pattern.editor, 40402) -- unquantize

    -- read notes
    retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(pattern.take)
    for trackNo = 0, gui.numOfTracks - 1, 1 do
        for noteIdx = 0, notecnt - 1, 1 do
            retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(pattern.take, noteIdx)
            if chan == trackNo then
                posStart = ppq2patternPosition(startppqpos)
                posEnd = ppq2patternPosition(endppqpos)

                if posStart < pattern.steps and posEnd <= pattern.steps then
                    -- place note end into pattern (do not place last note end behind pattern - pattern boundary will end it automatically)
                    if (posEnd < pattern.steps) then
                        rec = {}
                        rec.pitch = NOTE_OFF
                        pattern.setRecord(posEnd, trackNo, rec)
                    end
                    -- place note into pattern
                    rec = {}
                    rec.pitch = pitch
                    rec.velocity = vel
                    pattern.setRecord(posStart, trackNo, rec)
                end
            end
        end
        -- TODO grid size
    end

    -- save it back again (applies quantization etc...)
    saveMidiClip()
end

-- save pattern data to midi clip
function saveMidiClip()

    -- delete all notes in midi clip
    retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(pattern.take)
    for i = 0, notecnt, 1 do
        reaper.MIDI_DeleteNote(pattern.take, 0)
    end

    updateEditorGrid()

    -- write new events to midi clip
    for patternPosition = 0, pattern.steps - 1, 1 do
        for trackNo = 0, gui.numOfTracks, 1 do
            record = pattern.getRecord(patternPosition, trackNo)
            if record ~= nil then
                if record.pitch ~= nil and record.pitch ~= NOTE_OFF then
                    noteStart = patternPosition
                    noteLength = getPatternNoteLength(patternPosition, trackNo)
                    reaper.MIDI_InsertNote(pattern.take, false, false,
                        patternPosition2ppq(noteStart),
                        patternPosition2ppq(noteStart) + patternPosition2ppq(noteLength),
                        trackNo,
                        record.pitch,
                        record.velocity,
                        0)
                end
            end
        end
    end

    savePatternSysexProperties()
    -- todo is swing then call quantize on midi editor
    reaper.MIDIEditor_OnCommand(pattern.editor, 40003) -- select all
    reaper.MIDIEditor_OnCommand(pattern.editor, 40729) -- quantize to grid
    reaper.MIDIEditor_OnCommand(pattern.editor, 40214) -- unselect all
end

function setColorByLine(lineno)
    if lineno % gui.gridSize == 0 then
        setColor(WHITE_BRIGHT)
    else
        setColor(WHITE)
    end
end

function drawPatternLineNumber(lineno, hiddenRecords)
    setColorByLine(lineno + cursor.patternOffsetLines) -- todo
    gfx.x = gui.lineColOffset
    gfx.y = gui.patternLine2y(lineno)
    gfx.printf("%02d%s", lineno + cursor.patternOffsetLines, hiddenRecords and '.' or '')
end

function drawPatternLine(line)
    drawPatternLineNumber(line, true)
    for trackNo = 0, gui.numOfTracks, 1 do
        trackRec = pattern.getRecord(cursor.toPatternIndex(line + cursor.patternOffsetLines), trackNo)
        drawTrackEntry(trackRec, line, trackNo)
    end
end


function drawAllTracks()

    local numOfLines = gui.getNumOfVisiblePatternLines()
    if numOfLines <= 1 then
        numOfLines = 2 -- always draw at least zero line
    end
    for idx = 0, numOfLines - 1, 1 do
        drawPatternLine(idx)
    end

    -- all tracks
    --for i = 0, gui.numOfTracks - 1, 1 do
    --        drawTrack(i)
    --    end
end

function drawMenus()
    setColor(WHITE)
    gfx.x = 0
    gfx.y = 0
    gfx.printf("Grid: 1/%d  Step: %s  Edit mode: %s  Loud mode: %s  Octave: %s", gui.gridSize, gui.stepSize, gui.toOnOffString(gui.editMode), gui.toOnOffString(gui.loudMode), gui.octave + 1)
end


function savePatternSysexProperties()
    for i = 0, 16, 1 do reaper.MIDI_DeleteTextSysexEvt(pattern.take, 0) end
    reaper.MIDI_InsertTextSysexEvt(pattern.take, false, false, 0, 1, gui.gridSize)
    --reaper.MIDI_InsertTextSysexEvt(pattern.take, false, false, 0, 1, pattern.swing)
end

function loadPatternSysexProperties()
    local prop
    prop = getSysexProperty(0)
    if prop then gui.gridSize = tonumber(prop) end
    if gui.gridSize == nil or gui.gridSize < 1 then gui.gridSize = 16 end

    --prop = getSysexProperty(1)
    --if prop then pattern.swing = tonumber(prop) or 0 end

    -- todo more properties
end

function getSysexProperty(idx)
    retval, b, c, d, e, data = reaper.MIDI_GetTextSysexEvt(pattern.take, idx)
    return data:sub(0, data:len() - 1)
end

function update()
    gui.update(pattern.steps)
    drawMenus()
    drawAllTracks()
    gfx.clear = 0 -- background color
    gfx.update()
end


lastPatternUpdateTime = 0
lastPatternLoadTime = 0
function loop()
    keyWasPressed = processKeyboard()
    if keyWasPressed == true then
        update()
    end

    -- do not save pattern to midi clip immediately, but update after no edit for some time
    local now = math.floor(os.clock())
    if gui.editMode == true and lastPatternUpdateTime ~= lastPatternEditTime and now - lastPatternEditTime > MIDI_CLIP_SAVE_UPDATE_TIME then
        saveMidiClip()
        lastPatternUpdateTime = lastPatternEditTime
    end

    -- if not in editing mode, update pattern from its original midi clip periodically
-- temp disabled due to @see todo
--    if not gui.editMode and now - lastPatternLoadTime > MIDI_CLIP_LOAD_UPDATE_TIME then
--        dbg("load")
--        loadMidiClip()
--        lastPatternLoadTime = now
--    end

    muteTones()
    update()
    reaper.defer(loop)
end

init()

--debugColumns()
loop()

