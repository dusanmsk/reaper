--[[
Keys:
f2 - decrease grid size
f3 - increase grid size
f4 - turn on loud mode
space - toggle play

TODO:   - storage pre track bude vzdy 1 step = 1/128
        - grid bude mat vplyv len na zobrazovanie
        - pokial sa v patterne nachadza zaznam mimo grid, zobrazi sa v danom riadku upozornenie


TODO:   swing
TODO:   grid size zobrazovat ako 1/32 atd...

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
gui.selectionMode = false
gui.loudMode = false
gui.stepSize = 1
gui.gridSize = 128

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

-- convert gui pattern line to pattern index
-- handles scrolling and todo grid
gui.toPatternIndex = function(line)
    -- todo grid
    return line + cursor.patternOffsetLines
end



cursor = {}
cursor.track = 0
cursor.column = 0
cursor.line = 0
cursor.down = function()
    for i = 1, gui.stepSize, 1 do
        cursor.line = cursor.line + 1
        if cursor.line > gui.patternVisibleLines - 1 then cursor.line = gui.patternVisibleLines - 1; pattern.scrollDown(); end
    end
    -- todo
end
cursor.up = function()
    -- todo
    for i = 1, gui.stepSize, 1 do
        cursor.line = cursor.line - 1
        if cursor.line < 0 then cursor.line = 0; pattern.scrollUp(); end
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
    cursor.patternOffsetLines = cursor.patternOffsetLines + gui.patternVisibleLines
    if cursor.patternOffsetLines > pattern.steps - gui.patternVisibleLines then
        cursor.patternOffsetLines = pattern.steps - gui.patternVisibleLines
        cursor.line = gui.patternVisibleLines - 1
    end
end
cursor.pageUp = function()
    cursor.patternOffsetLines = cursor.patternOffsetLines - gui.patternVisibleLines
    if (cursor.patternOffsetLines < 0) then
        cursor.patternOffsetLines = 0
        cursor.line = 0
    end
end


MIDI_CLIP_UPDATE_TIME = 0.5


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
global.octave = 4

function dbg(m)
    return reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

function trace()
    dbg(debug.traceback())
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
    if cursor.patternOffsetLines > pattern.steps - gui.patternVisibleLines then cursor.patternOffsetLines = pattern.steps - gui.patternVisibleLines; end
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
    gfx.init("", 800, 800, 0)
    gfx.setfont(1, "Monospace", gui.fontsize)
    gfx.clear = 55
    gfx.dock(1) -- todo store/restore

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
        dbg(pattern.take)
        pattern.item = reaper.GetMediaItemTake_Item(pattern.take)
        dbg(pattern.item)
        itemLengthSec = reaper.GetMediaItemInfo_Value(pattern.item, 'D_LENGTH')
        retval, measuresOutOptional, cmlOutOptional, fullbeatsOutOptional, cdenomOutOptional = reaper.TimeMap2_timeToBeats(0, itemLengthSec)
        pattern.init(beatsToPatternSteps(fullbeatsOutOptional))
        pattern.swing = 0
        loadMidiClip(parseSysex)
        update()
    end
end

function beatsToPatternSteps(beats)
    -- 1 beat = 32 1/128 notes
    return math.floor(beats * 32) + 1
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
    return global.octave
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
    global.octave = global.octave + how
    if global.octave < 0 then global.octave = 0 end
    if global.octave > 6 then global.octave = 6 end
end

lastEditTime = 0
function emitEdited()
    lastEditTime = os.clock()
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
    if isKey(key, '`') then pitch = NOTE_OFF end

    if pitch ~= nil then
        rec = insertNoteAtCursor()
        generateTone(rec.pitch)
        cursor.down()
        emitEdited()
    end
end


function insertNoteAtCursor()
    patternIndex = gui.toPatternIndex(cursor.line)
    rec = pattern.getRecord(patternIndex, cursor.track)
    if rec == nil then rec = {} end
    rec.pitch = toPitch(pitch)
    if rec.pitch ~= NOTE_OFF then
        rec.velocity = 50
    end
    pattern.setRecord(patternIndex, cursor.track, rec)
    return rec
end

function deleteUnderCursor()
    -- todo do not delete whole line, but only what is under cursor
    deleteRecord(gui.toPatternIndex(cursor.line), cursor.track)
    processKey(keycodes.downArrow)
end


function isKey(key, ch)
    return string.byte(ch) == key
end

function decrementGrid()
    gui.gridSize = gui.gridSize * 2
    if gui.gridSize > 128 then gui.gridSize = 128 end
    savePatternSysexProperties()
end

function incrementGrid()
    gui.gridSize = gui.gridSize / 2
    if gui.gridSize < 1 then gui.gridSize = 1 end
    savePatternSysexProperties()
end


function incrementSwing()
    pattern.swing = pattern.swing + 1;
    if pattern.swing > 50 then pattern.swing = 50 end -- note internal max value is 50, shown as 100 in gui
    emitEdited()
end

function decrementSwing()
    pattern.swing = pattern.swing - 1;
    if pattern.swing < 0 then pattern.swing = 0 end
    emitEdited()
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
        dbg("play")
        rec = getOrCreateRecord(cursor.track, recordIndex(cursor.line))
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
        dbg("Key press: " .. key)
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
        if key == keycodes.escKey then global.selectionMode = not global.selectionMode end
        if key == keycodes.f2 then decrementGrid() end
        if key == keycodes.f3 then incrementGrid() end
        if key == keycodes.f4 then decrementSwing() end
        if key == keycodes.f5 then incrementSwing() end
        if key == keycodes.f6 then decrementStepSize() end
        if key == keycodes.f7 then incrementStepSize() end
        if key == keycodes.f8 then gui.loudMode = not gui.loudMode; playSelectedLine(); end
        if key == keycodes.space then reaperTogglePlay() end

        notePressed(key)
        return true
    end
    return false
end

function reaperTogglePlay()
    -- todo seek cursor
    local cursorLinePosition = recordIndex(cursor.line)
    local beats = linesToBeats(cursorLinePosition)
    local patternItemPositionSec = reaper.TimeMap2_beatsToTime(0, beats, 0)
    local itemPositionSec = reaper.GetMediaItemInfo_Value(global.selectedItem, "D_POSITION")
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


-- loads data from midi clip
function loadMidiClip(parseSysex)

    -- todo unquantize original midi clip by reaper action before read
    reaper.MIDIEditor_OnCommand(pattern.editor, 40003)      -- select all
    reaper.MIDIEditor_OnCommand(pattern.editor, 40402)      -- unquantize

    -- read pattern properties from sysex
    if parseSysex then
        loadPatternSysexProperties()
    end
    -- read notes
    retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(pattern.take)
    for trackNo = 0, gui.numOfTracks - 1, 1 do
        for noteIdx = 0, notecnt - 1, 1 do
            retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(pattern.take, noteIdx)
            if chan == trackNo then
                posStart = ppq2patternPosition(startppqpos)
                posEnd = ppq2patternPosition(endppqpos)
                --[[
                    -- todo "quantize" during parsing - will de-swing swinged midi clip
                    -- round by 0.5 down or up
                    linestart = round(linestart)
                    lineend = round(lineend)
                ]]
                -- place noteoff into pattern
                if posStart < pattern.steps and posEnd < pattern.steps then
                    rec = {}
                    rec.pitch = NOTE_OFF
                    dbg(posEnd)
                    pattern.setRecord(posEnd, trackNo, rec)
                    dbg("noteoff placed at " .. posEnd)

                    -- place note into pattern
                    rec = {}
                    rec.pitch = pitch
                    rec.velocity = vel
                    pattern.setRecord(posStart, trackNo, rec)
                    dbg("note placed at " .. posStart)
                end
            end
        end
        -- TODO grid size
        -- TODO swing?
    end

    -- save it back again (applies quantization etc...)
    saveMidiClip()
end

-- save pattern data to midi clip
function saveMidiClip()
    reaper.Undo_BeginBlock2(0)

    -- delete all notes in midi clip
    retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(pattern.take)
    for i = 0, notecnt, 1 do
        reaper.MIDI_DeleteNote(pattern.take, 0)
    end

    -- write new events to midi clip
    for patternPosition = 0, pattern.steps - 1, 1 do
        for trackNo = 0, gui.numOfTracks, 1 do
            record = pattern.getRecord(patternPosition, trackNo)
            if record ~= nil then
                if record.pitch ~= nil and record.pitch ~= NOTE_OFF then
                    noteStart = patternPosition
                    noteLength = getPatternNoteLength(patternPosition, trackNo)
                    --[[
                        swing disabled, will use reaper actions to re-swing it
                        if pattern.swing > 0 then
                            if patternPosition % 2 == 0 then
                                noteLength = noteLength + pattern.swing / 100
                            else
                                noteStart = noteStart + pattern.swing / 100
                                noteLength = noteLength - pattern.swing / 100
                            end
                        end
                    ]]
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

    -- write pattern settings into sysex event
    savePatternSysexProperties()
    reaper.Undo_EndBlock2(0, "Pattern editor", 0)

    -- todo is swing then call quantize on midi editor
    reaper.MIDIEditor_OnCommand(pattern.editor, 40003)      -- select all
    reaper.MIDIEditor_OnCommand(pattern.editor, 40729)      -- quantize to grid
end

function savePatternSysexProperties()
    reaper.Undo_BeginBlock2(0)
    for i = 0, 16, 1 do reaper.MIDI_DeleteTextSysexEvt(pattern.take, 0) end
    reaper.MIDI_InsertTextSysexEvt(pattern.take, false, false, 0, 1, gui.gridSize)
    reaper.MIDI_InsertTextSysexEvt(pattern.take, false, false, 0, 1, pattern.swing)
    reaper.Undo_EndBlock2(0, "Pattern properties", 0)
end

function loadPatternSysexProperties()
    local prop
    prop = getSysexProperty(0)
    if prop then gui.gridSize = tonumber(prop) or 8 end
    if gui.gridSize == nil or gui.gridSize < 1 then gui.gridSize = 8 end

    prop = getSysexProperty(1)
    if prop then pattern.swing = tonumber(prop) or 0 end

    -- todo more properties
end


function getSysexProperty(idx)
    retval, b, c, d, e, data = reaper.MIDI_GetTextSysexEvt(pattern.take, idx)
    return data:sub(0, data:len() - 1)
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
        trackRec = pattern.getRecord(gui.toPatternIndex(line), trackNo)
        drawTrackEntry(trackRec, line, trackNo)
    end
end

function drawAllTracks()

    local numOfLines = pattern.steps * (gui.gridSize / 128)
    if numOfLines > gui.patternVisibleLines then numOfLines = gui.patternVisibleLines end
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
    gfx.printf("Grid: 1/%d  Step: %s  Edit mode: %s  Loud mode: %s  Swing: %s", gui.gridSize, gui.stepSize, gui.toOnOffString(gui.selectionMode), gui.toOnOffString(gui.loudMode), pattern.swing * 2)
end


function update()
    gui.update(pattern.steps)
    drawMenus()
    drawAllTracks()
    gfx.clear = 0 -- background color
    gfx.update()
end


lastUpdateTime = 0
function loop()
    keyWasPressed = processKeyboard()
    if keyWasPressed == true then
        update()
    end
    -- do not update immediately, but update after no edit for some time
    if lastUpdateTime ~= lastEditTime and os.clock() - lastEditTime > MIDI_CLIP_UPDATE_TIME then
        saveMidiClip()
        lastUpdateTime = lastEditTime
    end

    muteTones()
    update()
    reaper.defer(loop)
end

init()

--debugColumns()
loop()


--draw(0,0, "C-4", 60, 250, 88)
--dbg(records[1].b)
--[[x = 40; y = 10
for idx, rec in ipairs(records) do
    dbg(rec.pitch)
    drawLineNo(10, y, idx)
    drawNote(x, y, rec.pitch, rec.velocity, rec.f1, rec.f2)
    y = y + gui.fontsize
end
]]
