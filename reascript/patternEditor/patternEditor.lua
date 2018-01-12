--[[
TODO: status line on top
TODO: beats for timing?

scrolling spravit tak, ze sa idealne oddeli zobrazovaci mechanizmus do extra classy.
jeho vstupom bude pattern a offset v patterne, od ktoreho ma zacat.
(napr. ak ma pattern 128 riadkov a zobrazuje sa len 32)

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

gui.update = function(patternLength)
    gui.displayLines = math.floor(gfx.h / gui.fontsize) - 1
    gui.patternVisibleLines = gui.displayLines - gui.patternStartLine
    if gui.patternVisibleLines > patternLength then gui.patternVisibleLines = patternLength end
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
keycodes.f2 = 26162
keycodes.f3 = 26163

global = {}
global.octave = 4
global.selectedItem = nil

function dbg(m)
    return reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

function err(m)
    msg = "Error" .. m
    dbg(msg)
end

tracks = {}
pattern = {}
pattern.steps = 0
pattern.offset = 0
pattern.linesPerBeat = 16
pattern.scrollUp = function()
    pattern.offset = pattern.offset - 1
    if pattern.offset < 0 then pattern.offset = 0; end
end
pattern.scrollDown = function()
    pattern.offset = pattern.offset + 1
    if pattern.offset > pattern.steps - gui.patternVisibleLines then pattern.offset = pattern.steps - gui.patternVisibleLines; end
end

cursor = {}
cursor.track = 0
cursor.column = 0
cursor.line = 0
cursor.down = function()
    cursor.line = cursor.line + 1
    if cursor.line > gui.patternVisibleLines - 1 then cursor.line = gui.patternVisibleLines - 1; pattern.scrollDown(); end
    -- todo
end
cursor.up = function()
    -- todo
    cursor.line = cursor.line - 1
    if cursor.line < 0 then cursor.line = 0; pattern.scrollUp(); end
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
    pattern.offset = pattern.offset + pattern.linesPerBeat * 2
    if pattern.offset > pattern.steps - gui.patternVisibleLines then
        pattern.offset = pattern.steps - gui.patternVisibleLines
        cursor.line = gui.patternVisibleLines - 1
    end
end
cursor.pageUp = function()
    pattern.offset = pattern.offset - pattern.linesPerBeat * 2
    if (pattern.offset < 0) then
        pattern.offset = 0
        cursor.line = 0
    end
end


WHITE = { r = 0.8, g = 0.8, b = 0.8 }
WHITE_BRIGHT = { r = 1.0, g = 1.0, b = 1.0 }
YELLOW = { r = 1.0, g = 1.0, b = 0.5 }
GREEN = { r = 0.0, g = 1.0, b = 0.0 }
BLACK = { r = 0.0, g = 0.0, b = 0.0 }
function setColor(color)
    gfx.set(color.r, color.g, color.b)
end


function beatsToLines(beats)
    return math.floor(pattern.linesPerBeat * beats)
end

function init()
    gfx.init("", 800, 800, 0)
    gfx.setfont(1, "Monospace", gui.fontsize)
    gfx.clear = 55
    gfx.dock(1) -- todo store/restore

    -- get basic informations from currently edited take
    -- TODO change to selected item instead of opened midi editor
end

function itemSelectionChanged()

    tracks = {}
    for i = 0, gui.numOfTracks, 1 do
        tracks[i] = {}
    end

    cursor.track = 0
    cursor.column = 0
    cursor.line = 0
    pattern.offset = 0

    if global.selectedItem == nil then
        pattern.steps = 32
        update()
        return
    end
    itemLengthSec = reaper.GetMediaItemInfo_Value(global.selectedItem, 'D_LENGTH')
    pattern.take = reaper.GetMediaItemTake(global.selectedItem, 0)
    retval, measuresOutOptional, cmlOutOptional, fullbeatsOutOptional, cdenomOutOptional = reaper.TimeMap2_timeToBeats(0, itemLengthSec)
    pattern.steps = beatsToLines(fullbeatsOutOptional) + 1
    loadMidiClip()
    update()
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

function patternLine2y(patternLine)
    return line2y(patternLine + gui.patternStartLine)
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
    local y = patternLine2y(line)
    if isSelected(line, trackNo, column) then
        local w, h = gfx.measurestr(value)
        setColor(GREEN)
        gfx.rect(x, y, w, h, 1)
        setColor(BLACK)
        gfx.x = x; gfx.y = y
        gfx.printf(value)
    else
        setColorByLine(line + pattern.offset)
        gfx.x = x; gfx.y = y
        gfx.printf(value)
    end
end


function drawTrackEntry(trackNo, line)
    trackData = tracks[trackNo]
    rec = trackData[line + pattern.offset]
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
        drawTrackEntry(trackNo, line)
    end
end

function getOrCreateRecord(trackNo, line)
    trackData = tracks[trackNo]
    rec = trackData[line]
    if rec == nil then
        rec = {}
        trackData[line] = rec
    end
    return rec
end

function deleteRecord(trackNo, line)
    trackData = tracks[trackNo]
    trackData[line] = nil
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

-- converts 'gui' line to record id
function recordIndex(line)
    return line + pattern.offset
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
        rec = getOrCreateRecord(cursor.track, recordIndex(cursor.line))
        rec.pitch = toPitch(pitch)
        if rec.pitch ~= NOTE_OFF then
            rec.velocity = 50
        end
        processKey(keycodes.downArrow)

        generateTone(rec.pitch)

        emitEdited()
    end
end

function deleteUnderCursor()
    trackNo = cursor.track
    -- todo do not delete whole line, but only what is under cursor
    deleteRecord(trackNo, recordIndex(cursor.line))
    processKey(keycodes.downArrow)
end


function isKey(key, ch)
    return string.byte(ch) == key
end

function decrementGrid()
    -- todo do not allow to decrement when real midi clip notes grid is smaller
    pattern.linesPerBeat = pattern.linesPerBeat / 2
    if pattern.linesPerBeat < 1 then pattern.linesPerBeat = 1 end
    itemSelectionChanged()
end

function incrementGrid()
    pattern.linesPerBeat = pattern.linesPerBeat * 2
    if pattern.linesPerBeat > 64 then pattern.linesPerBeat = 64 end
    itemSelectionChanged()
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
        if key == keycodes.downArrow then cursor.down() end
        if key == keycodes.upArrow then cursor.up() end
        if key == keycodes.rightArrow then cursor.right() end
        if key == keycodes.leftArrow then cursor.left() end
        if key == keycodes.octaveUp then changeOctave(1) end
        if key == keycodes.octaveDown then changeOctave(-1) end
        if key == keycodes.deleteKey then deleteUnderCursor() end
        if key == keycodes.homeKey then pattern.offset = 0 end
        if key == keycodes.endKey then pattern.offset = pattern.steps - gui.patternVisibleLines end
        -- todo checks inside patter class
        if key == keycodes.pageDown then cursor.pageDown() end
        if key == keycodes.pageUp then cursor.pageUp() end
        if key == keycodes.escKey then global.selectionMode = not global.selectionMode end
        if key == keycodes.f2 then decrementGrid() end
        if key == keycodes.f3 then incrementGrid() end

        notePressed(key)
        return true
    end
    return false
end

function line2ppq(lineNo)
    -- todo grid size
    return math.floor(lineNo * 480 / pattern.linesPerBeat * 2)
end

function ppq2line(ppq)
    -- todo grid size
    return math.floor(ppq / 480 * pattern.linesPerBeat / 2)
end


function deletePatternData(take)
    retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
    for i = 0, textsyxevtcnt - 1, 1 do
        retval, b, c, d, e, data = reaper.MIDI_GetTextSysexEvt(take, i)
        if (retval) then
            idx = string.find(data, "PATTERN")
            if idx == 1 then
                reaper.MIDI_DeleteTextSysexEvt(take, i)
            end
        end
    end
end

function storePatternData(take)
    -- pattern data is stored as midi text event. When using pattern editor, notes are not "parsed" from midi clip, but whole pattern context data are stored into special sysex text event inside midi clip.
    -- everytime pattern is edited, those data are read and all midi notes are regenerated from scratch

    -- delete old data
    deletePatternData(take)

    -- insert new data
    --    tracks_dump = serpent.dump(tracks)
    --    tracks_dump = "PATTERN_DATA:" .. tracks_dump
    --    reaper.MIDI_InsertTextSysexEvt(take, false, false, 1, 1, tracks_dump)
end

function getTakeLengthPPQ(take)
    item = reaper.GetMediaItemTake_Item(take)
    len_sec = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    return reaper.MIDI_GetPPQPosFromProjTime(take, len_sec)
end

function getNoteLengthLines(track, lineNo)
    -- iterate over track, note length is until (new note or note_off or pattern end) occure
    for i = lineNo + 1, pattern.steps, 1 do
        rec = track[i]
        if (rec ~= nil and rec.pitch ~= nil) then
            return i - lineNo
        end
    end
    return pattern.steps - lineNo
end


-- loads data from midi clip
function loadMidiClip()
    -- todo detect grid size from shortest midi note
    retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(pattern.take)
    for trackNo = 0, gui.numOfTracks - 1, 1 do
        for noteIdx = 0, notecnt - 1, 1 do
            retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(pattern.take, noteIdx)
            if chan == trackNo then
                linestart = ppq2line(startppqpos)
                lineend = ppq2line(endppqpos)

                -- place noteoff into pattern
                rec = getOrCreateRecord(trackNo, lineend + 1)
                -- dbg("noteoff placed at " .. lineend)
                rec.pitch = NOTE_OFF

                -- place note into pattern
                rec = getOrCreateRecord(trackNo, linestart)
                rec.pitch = pitch
                rec.velocity = vel
            end
        end
        -- TODO grid size
        -- TODO swing?
    end
end

-- save pattern data to midi clip
function saveMidiClip()
    reaper.Undo_BeginBlock2(0)
    storePatternData(pattern.take)

    -- delete all notes in midi clip
    retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(pattern.take)
    for i = 0, notecnt, 1 do
        reaper.MIDI_DeleteNote(pattern.take, 0)
    end

    -- write new events to midi clip
    for trackNo = 0, gui.numOfTracks, 1 do
        track = tracks[trackNo]
        for lineNo, record in pairs(track) do
            if record ~= nil then
                if record.pitch ~= nil and record.pitch ~= NOTE_OFF then
                    noteLength = getNoteLengthLines(track, lineNo)
                    -- dbg("note length " .. noteLength)
                    reaper.MIDI_InsertNote(pattern.take, false, false,
                        line2ppq(lineNo),
                        line2ppq(lineNo) + line2ppq(noteLength) - 1,
                        trackNo,
                        record.pitch,
                        record.velocity,
                        0)
                end
            end
        end
    end
    reaper.Undo_EndBlock2(0, "Pattern editor", 0)
end

function setColorByLine(lineno)
    if lineno % pattern.linesPerBeat == 0 then
        setColor(WHITE_BRIGHT)
    else
        setColor(WHITE)
    end
end

function drawPatternLineNumber(lineno)
    setColorByLine(lineno + pattern.offset)
    gfx.x = gui.lineColOffset
    gfx.y = patternLine2y(lineno)
    gfx.printf("%02d", lineno + pattern.offset)
end

function drawAllTracks()
    -- line numbers
    for idx = 0, gui.patternVisibleLines - 1, 1 do
        drawPatternLineNumber(idx)
    end
    -- all tracks
    for i = 0, gui.numOfTracks - 1, 1 do
        drawTrack(i)
    end
end

function drawMenus()
    setColor(WHITE)
    gfx.x = 0
    gfx.y = 0
    gfx.printf("Grid: %02d\nEdit mode: %s", pattern.linesPerBeat, (gui.selectionMode == false and 'off' or 'on'))
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

    item = reaper.GetSelectedMediaItem(0, 0)
    if global.selectedItem ~= item then
        global.selectedItem = item
        itemSelectionChanged()
    end

    muteTones()
    -- update()
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
