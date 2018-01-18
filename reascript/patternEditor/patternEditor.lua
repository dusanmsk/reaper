--[[
Keys:
f1 - decrease step size
f2 - increase step size
f3 - decrease grid size
f4 - increase grid size
f5 - refresh pattern (from reaper item, will be refreshed automatically when enabling edit mode)
f6 - turn on loud mode
f7 - toggle note length mode
space - toggle play
esc - toggle edit mode

TODO:


    - vobec nijak nie je poriesene ked loadujem midi clip ktory nepochadza z pattern editoru a su v nom paralelne noty.
    bud to poriesit nejak elegantne, alebo sa na to vykaslat a neumoznit editovat klipy ktore nemaju pattern editor sysexy
    Alebo loadovat s gridom 128 a potom shrinkovat kym to pojde automaticky

    Mozno by to slo spravit tak, ze pokial to nie je original "pattern" midi clip, pouzit nejaku special importovaciu funkciu,
    ktora by proste plnila tracky tak, ze pokial v tracku v danom bloku (ktory zabere prave parsovana nota) nic nehra,
    tak sa pouzije, inak sa pouzije dalsi track atd...

    - NOTE to ci je stlaceny shift/ctrl mozno pojde vycitat z mouse_cap

      TODO - obzivnut myslienku namiesto noteoff pouzivat notehold, tzn. pokail by nota mala byt na 4 riadky, tak nebude v strukture ulozena ako
      C-4
      nil
      nil
      nil
      NOTE-OFF

      ale
      C-4
      hold
      hold
      hold
      nil

      To umozni jednoduchsiu implementaciu bodu nadtymto - detekciu ci je stopa volna a ci je do nej mozne vlozit ton z midi clipu ktory nevznikol v pattern editore

      Takisto je potom moznost naimplementovat prepinanie rezimu zobrazovania v gui - bud postaru s noteoff, alebo ponovu s notehold

      Toto ale asi implikuje zmenu patternu z 1/128 natvrdo zase naspat tak, ze bude obsahovat tolko riadkov kolko sa zobrazuje na gui

    - odstranid posledne 2 stlpce z tracku - CC je globalne per midi klip, nedavaju zmysel per channel
    - loud mode bude mat 3 rezimy:
        - off
        - single track
        - multiple track (prehra vsetky noty zo vsetkych trackov)

]]

--[[
30 ppq = 1/128
 ]]


inspect = require 'inspect'

MIDI_CLIP_SAVE_UPDATE_TIME = 0.5
MIDI_CLIP_LOAD_UPDATE_TIME = 2


gui = {}
gui.fontsize = 20
gui.trackColumns = 4
gui.numOfTracks = 8
gui.displayLines = 32
gui.lineColOffset = 5
gui.lineColWidth = 33
gui.trackSize = 110
gui.patternStartLine = 3
gui.patternVisibleLines = 0
gui.patternOffset = 0
gui.loudMode = false
gui.stepSize = 1
gui.editMode = false
gui.octave = 4
gui.defaultVelocity = 32
gui.selectedTake = nil

cursor = {}
cursor.track = 0
cursor.column = 0
cursor.line = 0

NOTE_HOLD = -1

NOTE_HOLD_REC = { pitch = NOTE_HOLD }


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
keycodes.f1 = 26161
keycodes.f2 = 26162
keycodes.f3 = 26163
keycodes.f4 = 26164
keycodes.f5 = 26165
keycodes.f6 = 26166
keycodes.f7 = 26167
keycodes.f8 = 26168
keycodes.space = 32
keycodes.backslash = 92


pattern = {}
pattern.data = {}
pattern.editor = {}
pattern.item = nil
pattern.take = nil
pattern.steps = 0
gui.gridSize = 16


global = {}

function dbg(m)
    return reaper.ShowConsoleMsg(inspect.inspect(m) .. "\n")
end

function trace(m)
    dbg(m .. debug.traceback())
end

function err(m)
    msg = "Error" .. m
    dbg(msg)
end


function isNote(rec)
    return rec ~= nill and rec.pitch ~= nil and rec.pitch > 0
end

function isNoteHold(rec)
    return rec ~= nill and rec.pitch ~= nil and rec.pitch == NOTE_HOLD
end


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

-- convert gui line to pattern line
gui.guiToPatternLine = function(guiLine)
    return guiLine + gui.patternOffset
end

cursor.down = function()
    cursor.line = cursor.line + 1
    if cursor.line > gui.patternVisibleLines - 1 then
        cursor.line = gui.patternVisibleLines - 1;
        gui.patternOffset = gui.patternOffset + 1
        if gui.patternOffset > pattern.steps - gui.patternVisibleLines then gui.patternOffset = pattern.steps - gui.patternVisibleLines end
    end
end
cursor.up = function()
    -- todo
    for i = 1, gui.stepSize, 1 do
        cursor.line = cursor.line - 1
        if cursor.line < 0 then
            cursor.line = 0;
            gui.patternOffset = gui.patternOffset - 1
            if gui.patternOffset < 0 then gui.patternOffset = 0 end
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
    for i = 1, gui.patternVisibleLines, 1 do
        cursor.down()
    end
end
cursor.pageUp = function()
    for i = 1, gui.patternVisibleLines, 1 do
        cursor.up()
    end
end


pattern.scrollUp = function()
    -- todo
    --[[
    cursor.patternOffsetLines = cursor.patternOffsetLines - 1
    if cursor.patternOffsetLines < 0 then cursor.patternOffsetLines = 0; end
    --]]
end
pattern.scrollDown = function()
    -- todo
    --[[
    cursor.patternOffsetLines = cursor.patternOffsetLines + 1
    local patternGuiLines = cursor.toGuiLine(pattern.steps)
    if cursor.patternOffsetLines > patternGuiLines - gui.getNumOfVisiblePatternLines() then
        cursor.patternOffsetLines = patternGuiLines - gui.getNumOfVisiblePatternLines();
    end
    --]]
end

pattern.init = function(steps)
    dbg("init " .. steps)
    pattern.steps = steps
    for i = 0, steps - 1, 1 do
        pattern.data[i] = {}
        for trackNo = 0, gui.numOfTracks, 1 do
            pattern.data[i][trackNo] = nil
        end
    end
end

pattern.getRecord = function(line, track)
    if pattern == nil or pattern.data == nil or pattern.data[line] == nil or pattern.data[line][track] == nil then return nil end
    return pattern.data[line][track]
end

pattern.setRecord = function(line, track, rec)
    dbg(line .. "," .. track)
    assert(line >= 0 and line < pattern.steps)
    assert(track >= 0 and track < gui.numOfTracks)
    pattern.data[line][track] = rec
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


function storeWindowDimensions()
    local d, x, y, w, h = gfx.dock(-1, 0, 0, 0, 0)
    if w > 0 and h > 0 then -- skip first run when windows is intialized with zeros
        reaper.SetExtState("pattern_editor", "window.x", tostring(x), false)
        reaper.SetExtState("pattern_editor", "window.y", tostring(y), false)
        reaper.SetExtState("pattern_editor", "window.w", tostring(w), false)
        reaper.SetExtState("pattern_editor", "window.h", tostring(h), false)
    end
end

function loadWindowDimensions()
    local x = tonumber(reaper.GetExtState("pattern_editor", "window.x")) or 100
    local y = tonumber(reaper.GetExtState("pattern_editor", "window.y")) or 100
    local w = tonumber(reaper.GetExtState("pattern_editor", "window.w")) or 200
    local h = tonumber(reaper.GetExtState("pattern_editor", "window.h")) or 200
    return x, y, w, h
end

function initGui()
    local x, y, w, h = loadWindowDimensions()
    gfx.quit()
    gfx.init("Pattern editor", w, h, 0, x, y)
    gfx.setfont(1, "Monospace", gui.fontsize)
    gfx.clear = 55
end

function exit()
    storeWindowDimensions()
end

function detectMidiClipGridSize(take)
    -- todo implement
    return 8
end

function takeChanged(editor, take)

    dbg("takechanged")
    gui.selectedTake = take

    storeWindowDimensions()
    initGui()

    pattern.data = {}
    pattern.steps = 0

    cursor.track = 0
    cursor.column = 0
    cursor.line = 0
    gui.patternOffset = 0

    if gui.selectedTake ~= nil then
        pattern.editor = editor
        pattern.take = take
        pattern.item = reaper.GetMediaItemTake_Item(take)
        if pattern.take then
            gui.gridSize = 128
            itemLengthSec = reaper.GetMediaItemInfo_Value(pattern.item, 'D_LENGTH')
            retval, measuresOutOptional, cmlOutOptional, fullbeatsOutOptional, cdenomOutOptional = reaper.TimeMap2_timeToBeats(0, itemLengthSec)
            if retval then
                pattern.init(beatsToPatternLines(fullbeatsOutOptional, gui.gridSize))
                refreshPattern(true)
            end
        end
    end
end

function beatsToPatternLines(beats, gridSize)
    -- 1 beat = 32 1/128 notes or 2 1/8 notes or 1 1/4 note
    return math.floor(gridSize * beats / 4)
end

function patternLinesToBeats(lines, gridSize)
    return lines / gridSize * 4
end


noteStrings = { "C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-" }
function noteToString(pitch)
    if pitch == nil then return nil end
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
        setColorByLine(gui.guiToPatternLine(line))
        gfx.x = x; gfx.y = y
        gfx.printf(value)
    end
end


function drawTrackEntry(rec, line, trackNo)
    if rec ~= nil then
        if rec.pitch > 0 then
            drawCell(trackNo, line, 0, cellValue("%s", noteToString(rec.pitch), ' ---'))
            drawCell(trackNo, line, 1, cellValue("%02x", rec.velocity, '--'))
            drawCell(trackNo, line, 2, cellValue("%02x", rec.f1, '--'))
            drawCell(trackNo, line, 3, cellValue("%02x", rec.f2, '--'))
            drawCell(trackNo, line, 4, '|')
        elseif rec.pitch == NOTE_HOLD then
            drawCell(trackNo, line, 0, "  |")
            drawCell(trackNo, line, 1, "--")
            drawCell(trackNo, line, 2, "--")
            drawCell(trackNo, line, 3, "--")
            drawCell(trackNo, line, 4, '|')
        end
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
        rec = trackData[gui.guiToPatternLine(line)]
        drawTrackEntry(rec, trackNo, line)
    end
end

function deleteRecord(line, trackNo)
    local rec = pattern.getRecord(line, trackNo)
    pattern.setRecord(line, trackNo, nil)
    -- if deleting note or notehold then delete all noteholds behind
    if isNote(rec) or isNoteHold(rec) then
        for i = line + 1, pattern.steps, 1 do
            rec = pattern.getRecord(i, trackNo)
            if isNoteHold(rec) then
                pattern.setRecord(i, trackNo, nil)
            else
                break
            end
        end
    end
    emitEdited()
end


function getCurrentOctave()
    return gui.octave
end

function toPitch(pitch)
    if (pitch < 0) then return pitch end
    -- C-1 == 0, every octave +12
    return pitch + 12 * (getCurrentOctave() + 1)
end

currentToneTimestamps = {}
function generateTone(pitch)
    if pitch > 0 then
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
        refreshPattern(false)
    end
    gui.editMode = not gui.editMode
end

function insertRecordAt(patternIndex, rec)
    pattern.setRecord(patternIndex, cursor.track, rec)
    emitEdited()
end

function insertNoteOffAtCursor()
    -- todo pattern track will be internally filled with note_holds without gaps
    local line = gui.guiToPatternLine(cursor.line)
    pattern.setRecord(line, cursor.track, NOTE_HOLD_REC)
    -- go backwards and insert noteholds until first note will be found
    for i = line - 1, 0, -1 do
        local rec = pattern.getRecord(i, cursor.track)
        if isNote(rec) then
            break
        end
        pattern.setRecord(i, cursor.track, NOTE_HOLD_REC)
    end
    return true
end

function insertNoteAtCursor(pitch)
    local rec = getNoteAtCursor()
    if rec == nil then rec = {} end
    rec.pitch = toPitch(pitch)
    rec.velocity = rec.velocity or gui.defaultVelocity
    insertRecordAt(gui.guiToPatternLine(cursor.line), rec)
    return true
end

function refreshPattern(readSysexProperties)
    -- todo loadMidiClip(readSysexProperties)
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
    if isKey(key, '`') then pitch = NOTE_HOLD end

    local inserted = false
    local rec = nil
    if gui.editMode then
        if pitch ~= nil then
            if pitch == NOTE_HOLD then
                inserted = insertNoteOffAtCursor()
            else
                inserted = insertNoteAtCursor(pitch)
            end
            if inserted then
                cursor.down()
                emitEdited()
            end
            generateTone(toPitch(pitch))
        end
    end
end

function getNoteAtCursor()
    patternLine = gui.guiToPatternLine(cursor.line)
    return pattern.getRecord(patternLine, cursor.track)
end



function deleteUnderCursor()
    if not gui.editMode == true then return end
    -- todo do not delete whole line, but only what is under cursor
    deleteRecord(gui.guiToPatternLine(cursor.line), cursor.track)
    cursor.down()
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


function expandPattern()
    local newData = {}
    local writeLine = 0
    for readLine = 0, pattern.steps, 1 do
        newData[writeLine] = {}
        newData[writeLine + 1] = {}
        for track = 0, gui.numOfTracks - 1, 1 do
            local rec = pattern.getRecord(readLine, track)
            if rec ~= nil then
                newData[writeLine][track] = rec
                if rec.pitch ~= nil then
                    newData[writeLine + 1][track] = NOTE_HOLD_REC
                end
            end
        end
        writeLine = writeLine + 2
    end
    pattern.data = newData
    pattern.steps = pattern.steps * 2
end

function shrinkPattern()
    local newData = {}
    if not isPossibleToShrinkPattern() then return end
    local writeLine = 0
    for readLine = 0, pattern.steps, 2 do
        local rec = pattern.data[readLine]
        newData[writeLine] = rec
        writeLine = writeLine + 1
    end
    pattern.steps = math.floor(pattern.steps / 2)
    pattern.data = newData
end

function decrementGrid()
    -- todo expand noteholds
    gui.gridSize = gui.gridSize * 2
    if gui.gridSize > 128 then
        gui.gridSize = 128
        return
    end
    cursor.line = 0
    gui.patternOffset = 0
    expandPattern()
    saveMidiClip()
end

function incrementGrid()
    if not isPossibleToShrinkPattern() then return end
    shrinkPattern()
    gui.gridSize = gui.gridSize / 2
    if gui.gridSize < 1 then gui.gridSize = 1 end
    cursor.line = 0
    gui.patternOffset = 0
    savePatternSysexProperties()
    saveMidiClip()
end

function updateEditorGrid()
    local cmdId = gridSizeToSWSAction[gui.gridSize]
    if cmdId then reaper.MIDIEditor_LastFocused_OnCommand(cmdId, false) end
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
        local patternIndex = gui.guiToPatternLine(cursor.line)
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
        if key == keycodes.homeKey then gui.patternOffset = 0 end
        if key == keycodes.endKey then gui.patternOffset = pattern.steps - gui.patternVisibleLines; cursor.line = gui.patternVisibleLines - 1 end
        -- todo checks inside patter class
        if key == keycodes.pageDown then cursor.pageDown() end
        if key == keycodes.pageUp then cursor.pageUp() end
        if key == keycodes.f1 then decrementStepSize() end
        if key == keycodes.f2 then incrementStepSize() end
        if key == keycodes.f3 then decrementGrid() end
        if key == keycodes.f4 then incrementGrid() end
        if key == keycodes.f5 then refreshPattern() end
        if key == keycodes.f6 then gui.loudMode = not gui.loudMode; playSelectedLine(); end
        if key == keycodes.f7 then toggleNoteLengthMode() end
        if key == keycodes.space then reaperTogglePlay() end
        if key == keycodes.escKey then toggleEditMode() end

        notePressed(key)
        return true
    end
    return false
end


function reaperTogglePlay()
    -- todo seek cursor
    local patternIndex = gui.guiToPatternLine(cursor.line)
    local beats = patternStepsToBeats(patternIndex)
    local patternItemPositionSec = reaper.TimeMap2_beatsToTime(0, beats, 0)
    local itemPositionSec = reaper.GetMediaItemInfo_Value(pattern.item, "D_POSITION")
    local globalPositionSec = itemPositionSec + patternItemPositionSec
    reaper.Main_OnCommand(40044, 0) -- transport play/stop
    reaper.SetEditCurPos(globalPositionSec, true, true)
end

function line2ppq(position)
    -- 1/128 note = 30 ppq
    return math.floor(position * 30 * 128 / gui.gridSize)
end

function ppq2Line(position)
    -- 1/128 note = 30 ppq
    return math.floor(position / 30 / 128 * gui.gridSize)
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

-- return note length (in pattern steps)
function getPatternNoteLength(line, trackNo)
    -- iterate over track, note length is until end of note_hold block
    local noteLen = 1
    for i = line + 1, pattern.steps - 1, 1 do
        local rec = pattern.getRecord(i, trackNo)
        if isNoteHold(rec) then
            noteLen = noteLen + 1
        else
            break
        end
    end
    return noteLen
end


function isPossibleToShrinkPattern()
    -- todo prerobit nasledovne:
    -- na neparnych riadkoch nesmu byt noty
    -- bloky notehold za notami musia byt delitelne dvomi
    for line = 1, pattern.steps - 1, 2 do
        for track = 0, gui.numOfTracks, 1 do
            local rec = pattern.getRecord(line, track)
            if rec and rec.pitch > 0 then return false end
        end
    end
    -- every note must be shrinkable to half
    for track = 0, gui.numOfTracks, 1 do
        local noteLengthSum = 0
        for line = 0, pattern.steps - 1, 1 do
            local rec = pattern.getRecord(line, track)
            if isNote(rec) or isNoteHold(rec) then noteLengthSum = noteLengthSum + 1 end
        end
        if noteLengthSum % 2 ~= 0 then return false end
    end
    return true
end

-- loads data from midi clip
function loadMidiClip(readSysexProperties)

    if pattern.editor == nil then return end

    -- todo odstranit a prepisat loading
    if readSysexProperties then loadPatternSysexProperties() end

    -- todo unquantize original midi clip by reaper action before read

    reaper.MIDIEditor_LastFocused_OnCommand(40003, false) -- select all
    reaper.MIDIEditor_LastFocused_OnCommand(40402, false) -- unquantize

    -- read notes
    retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(pattern.take)
    for trackNo = 0, gui.numOfTracks - 1, 1 do
        for noteIdx = 0, notecnt - 1, 1 do
            retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(pattern.take, noteIdx)
            if chan == trackNo then
                posStart = ppq2Line(startppqpos)
                posEnd = ppq2Line(endppqpos)

                if posStart < pattern.steps and posEnd <= pattern.steps then

                    -- todo prerobit na notehold
                    --[[
                        -- place note end into pattern (do not place last note end behind pattern - pattern boundary will end it automatically)
                        if (posEnd < pattern.steps and pattern.noteLengthModeWASREMOVED == "full") then
                            rec = {}
                            rec.pitch = NOTE_OFF
                            pattern.setRecord(posEnd, trackNo, rec)
                        end
                        -- place note into pattern
                        rec = {}
                        rec.pitch = pitch
                        rec.velocity = vel
                        pattern.setRecord(posStart, trackNo, rec)
                    --]]
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

    if pattern.editor == nil then return end

    -- delete all notes in midi clip
    retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(pattern.take)
    for i = 0, notecnt, 1 do
        reaper.MIDI_DeleteNote(pattern.take, 0)
    end

    updateEditorGrid()

    -- write new events to midi clip
    for line = 0, pattern.steps - 1, 1 do
        for trackNo = 0, gui.numOfTracks, 1 do
            record = pattern.getRecord(line, trackNo)
            if record ~= nil then
                if record.pitch ~= nil and record.pitch > 0 then
                    noteStart = line
                    noteLength = getPatternNoteLength(line, trackNo)
                    reaper.MIDI_InsertNote(pattern.take, false, false,
                        line2ppq(noteStart),
                        line2ppq(noteStart + noteLength),
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
    -- todo open editor, do action, close editor
    reaper.MIDIEditor_LastFocused_OnCommand(40003, false) -- select all
    reaper.MIDIEditor_LastFocused_OnCommand(40729, false) -- quantize to grid
    reaper.MIDIEditor_LastFocused_OnCommand(40214, false) -- unselect all
end

function setColorByLine(lineno)
    if lineno % gui.gridSize == 0 then
        setColor(WHITE_BRIGHT)
    else
        setColor(WHITE)
    end
end

function drawPatternLineNumber(lineno)
    setColorByLine(gui.guiToPatternLine(lineno)) -- todo
    gfx.x = gui.lineColOffset
    gfx.y = gui.patternLine2y(lineno)
    gfx.printf("%02d", gui.guiToPatternLine(lineno))
end

function drawPatternLine(line)
    drawPatternLineNumber(line)
    for trackNo = 0, gui.numOfTracks, 1 do
        trackRec = pattern.getRecord(gui.guiToPatternLine(line), trackNo)
        drawTrackEntry(trackRec, line, trackNo)
    end
end


function drawPatternArea()
    if pattern.steps > 0 then
        local numOfLines = gui.patternVisibleLines
        if numOfLines <= 1 then
            numOfLines = 2 -- always draw at least zero line
        end
        for line = 0, numOfLines - 1, 1 do
            drawPatternLine(line)
        end
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
end

function loadPatternSysexProperties()
    gui.gridSize = 128
    local prop = getSysexProperty(0)
    if prop then gui.gridSize = tonumber(prop) end

    -- todo more properties
end

function getSysexProperty(idx)
    retval, b, c, d, e, data = reaper.MIDI_GetTextSysexEvt(pattern.take, idx)
    if retval then return data:sub(0, data:len() - 1) else return nil end
end

function update()
    gui.update(pattern.steps)
    drawMenus()
    drawPatternArea()
    gfx.clear = 0 -- background color
    gfx.update()
end


lastPatternUpdateTime = 0
lastPatternLoadTime = 0
function loop()

    local editor = reaper.MIDIEditor_GetActive()
    local take = reaper.MIDIEditor_GetTake(editor)
    if gui.selectedTake ~= take then
        takeChanged(editor, take)
    end

    keyWasPressed = processKeyboard()

    -- do not save pattern to midi clip immediately, but update after no edit for some time
    local now = math.floor(os.clock())
    if gui.editMode == true and lastPatternUpdateTime ~= lastPatternEditTime and now - lastPatternEditTime > MIDI_CLIP_SAVE_UPDATE_TIME then
        saveMidiClip()
        lastPatternUpdateTime = lastPatternEditTime
    end

    muteTones()
    update()
    reaper.defer(loop)
end


reaper.atexit(exit)



--debugColumns()
loop()

