local mq = require('mq')
local ImGui = require('ImGui')
local helpers = require('booty.helpers')
local Parser = require('booty.filter.parser')

local FilterGUI = {}

-- ============================================================================
-- STATE
-- ============================================================================
local state = {
    open = true,
    available_filters = {},
    lines = {},
    filter_name = "",
    new_filter_name = "",
    test_results = {},
    show_matches_only = true,
    new_line_type = 0,
    new_line_text = "",
}

local LINE_TYPES = { "Name", "Pattern", "Value", "Flag", "Slot", "AugType", "Comment" }

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function get_filters_path()
    return string.format("%s/lua/booty/filters/", mq.TLO.MacroQuest.Path())
end

local function scan_available_filters()
    state.available_filters = {}
    local path = get_filters_path()

    -- Try lfs if available
    local ok, lfs = pcall(require, 'lfs')
    if ok and lfs and lfs.dir then
        pcall(function()
            for file in lfs.dir(path) do
                if file:match("%.txt$") then
                    table.insert(state.available_filters, file:gsub("%.txt$", ""))
                end
            end
        end)
    end

    -- Fallback: probe common names
    if #state.available_filters == 0 then
        local names = {"default","whitelist","blacklist","vendor","keep","trash","augments","collectibles","loot","sell","test"}
        for _, name in ipairs(names) do
            local f = io.open(path .. name .. ".txt", "r")
            if f then
                f:close()
                table.insert(state.available_filters, name)
            end
        end
    end

    table.sort(state.available_filters)
end

local function parse_line_type(line)
    line = (line or ""):match("^%s*(.-)%s*$") or ""
    if line == "" then return "Blank", ""
    elseif line:match("^#") then return "Comment", line:sub(2):match("^%s*(.-)%s*$") or ""
    elseif line:match("^Value:") then return "Value", line:match("^Value:%s*(.+)") or ""
    elseif line:match("^Flag:") then return "Flag", line:match("^Flag:%s*(.+)") or ""
    elseif line:match("^Slot:") then return "Slot", line:match("^Slot:%s*(.+)") or ""
    elseif line:match("^AugType:") then return "AugType", line:match("^AugType:%s*(.+)") or ""
    elseif line:match("^Pattern:") then return "Pattern", line:match("^Pattern:%s*(.+)") or ""
    elseif line:match("^Name:") then return "Name", line:match("^Name:%s*(.+)") or ""
    else return "Name", line
    end
end

local function reconstruct_line(line_type, text)
    if line_type == "Comment" then return "# " .. text
    elseif line_type == "Blank" then return ""
    elseif line_type == "Name" then return text
    else return line_type .. ": " .. text
    end
end

local function load_filter(filter_name)
    state.filter_name = filter_name
    state.lines = {}
    state.test_results = {}

    local path = get_filters_path() .. filter_name .. ".txt"
    local f = io.open(path, "r")
    if not f then
        helpers.error("Could not open: " .. path)
        return false
    end

    for line in f:lines() do
        local lt, txt = parse_line_type(line)
        table.insert(state.lines, { type = lt, text = txt, enabled = true })
    end
    f:close()
    helpers.success("Loaded: " .. filter_name .. " (" .. #state.lines .. " lines)")
    return true
end

local function save_filter()
    if state.filter_name == "" then return false end
    local path = get_filters_path() .. state.filter_name .. ".txt"
    local f = io.open(path, "w")
    if not f then
        helpers.error("Could not save: " .. path)
        return false
    end
    for _, line in ipairs(state.lines) do
        f:write(reconstruct_line(line.type, line.text) .. "\n")
    end
    f:close()
    helpers.success("Saved: " .. state.filter_name)
    return true
end

local function get_inventory_items()
    local items = {}
    local cursor = mq.TLO.Cursor
    if cursor() then
        table.insert(items, { item = cursor, name = cursor.Name() or "?", location = "Cursor", value = cursor.Value() or 0 })
    end
    for i = 1, 10 do
        local pack = mq.TLO.Me.Inventory("pack" .. i)
        if pack() then
            for j = 1, (pack.Container() or 0) do
                local item = pack.Item(j)
                if item() then
                    table.insert(items, { item = item, name = item.Name() or "?", location = string.format("Bag%d Slot%d", i, j), value = item.Value() or 0 })
                end
            end
        end
    end
    return items
end

local function test_line(idx)
    local line = state.lines[idx]
    if not line or line.type == "Comment" or line.type == "Blank" then return end
    local raw = reconstruct_line(line.type, line.text)
    local rule = Parser.parse_line(raw)
    if not rule then return end

    state.test_results = {}
    for _, inv in ipairs(get_inventory_items()) do
        local ok, matched = pcall(rule, inv.item)
        table.insert(state.test_results, { name = inv.name, location = inv.location, value = inv.value, matched = ok and matched, matched_line = (ok and matched) and idx or nil })
    end
end

local function test_all()
    state.test_results = {}
    local rules = {}
    for idx, line in ipairs(state.lines) do
        if line.type ~= "Comment" and line.type ~= "Blank" and line.enabled then
            local raw = reconstruct_line(line.type, line.text)
            local rule = Parser.parse_line(raw)
            if rule then table.insert(rules, { idx = idx, func = rule }) end
        end
    end

    for _, inv in ipairs(get_inventory_items()) do
        local matched, matched_line = false, nil
        for _, r in ipairs(rules) do
            local ok, res = pcall(r.func, inv.item)
            if ok and res then
                matched, matched_line = true, r.idx
                break
            end
        end
        table.insert(state.test_results, { name = inv.name, location = inv.location, value = inv.value, matched = matched, matched_line = matched_line })
    end
end

-- ============================================================================
-- GUI RENDER LOOP (matches HUD pattern)
-- ============================================================================

local function FilterGUI_Loop()
    if not state.open then return end

    ImGui.SetNextWindowSize(ImVec2(900, 500), ImGuiCond.FirstUseEver)

    if ImGui.Begin("Booty Filter Editor", state.open) then
        -- LEFT: Filter list
        ImGui.BeginChild("left", ImVec2(140, 0), true)
        ImGui.Text("Filters")
        if ImGui.Button("Refresh") then scan_available_filters() end
        ImGui.Separator()
        for _, name in ipairs(state.available_filters) do
            if ImGui.Selectable(name, name == state.filter_name) then
                load_filter(name)
            end
        end
        ImGui.Separator()
        ImGui.Text("New:")
        state.new_filter_name = ImGui.InputText("##new", state.new_filter_name or "", 32)
        if ImGui.Button("Create") and state.new_filter_name ~= "" then
            local Filter = require('booty.filter')
            Filter.create_skeleton(state.new_filter_name)
            scan_available_filters()
            load_filter(state.new_filter_name)
            state.new_filter_name = ""
        end
        ImGui.EndChild()

        ImGui.SameLine()

        -- MIDDLE: Line editor
        ImGui.BeginChild("mid", ImVec2(420, 0), true)
        if state.filter_name == "" then
            ImGui.Text("Select a filter")
        else
            ImGui.Text("Editing: " .. state.filter_name)
            if ImGui.Button("Save") then save_filter() end
            ImGui.SameLine()
            if ImGui.Button("Test All") then test_all() end
            ImGui.SameLine()
            if ImGui.Button("Reload") then load_filter(state.filter_name) end
            ImGui.Separator()

            local to_del = nil
            for idx, line in ipairs(state.lines) do
                ImGui.PushID(idx)
                -- Line #
                if line.type == "Comment" or line.type == "Blank" then
                    ImGui.TextDisabled(string.format("%02d", idx))
                else
                    ImGui.Text(string.format("%02d", idx))
                end
                ImGui.SameLine()

                -- Type combo
                ImGui.SetNextItemWidth(75)
                local tidx = 0
                for i, t in ipairs(LINE_TYPES) do
                    if t == line.type then tidx = i - 1 break end
                end
                local newtidx = ImGui.Combo("##t", tidx, LINE_TYPES)
                if newtidx ~= tidx then line.type = LINE_TYPES[newtidx + 1] end
                ImGui.SameLine()

                -- Text
                ImGui.SetNextItemWidth(180)
                line.text = ImGui.InputText("##v", line.text or "", 128)
                ImGui.SameLine()

                -- Test btn
                if line.type ~= "Comment" and line.type ~= "Blank" then
                    if ImGui.Button("T##") then test_line(idx) end
                else
                    ImGui.TextDisabled(" ")
                end
                ImGui.SameLine()

                -- Delete
                if ImGui.Button("X##") then to_del = idx end
                ImGui.PopID()
            end
            if to_del then table.remove(state.lines, to_del) end

            ImGui.Separator()
            ImGui.Text("Add:")
            ImGui.SameLine()
            ImGui.SetNextItemWidth(75)
            state.new_line_type = ImGui.Combo("##nt", state.new_line_type or 0, LINE_TYPES)
            ImGui.SameLine()
            ImGui.SetNextItemWidth(150)
            state.new_line_text = ImGui.InputText("##nv", state.new_line_text or "", 128)
            ImGui.SameLine()
            if ImGui.Button("Add") then
                table.insert(state.lines, { type = LINE_TYPES[(state.new_line_type or 0) + 1], text = state.new_line_text or "", enabled = true })
                state.new_line_text = ""
            end
        end
        ImGui.EndChild()

        ImGui.SameLine()

        -- RIGHT: Results
        ImGui.BeginChild("right", ImVec2(0, 0), true)
        ImGui.Text("Results")
        ImGui.SameLine()
        state.show_matches_only = ImGui.Checkbox("Matches", state.show_matches_only)
        ImGui.Separator()

        if #state.test_results == 0 then
            ImGui.TextDisabled("Run a test")
        else
            local cnt = 0
            for _, r in ipairs(state.test_results) do if r.matched then cnt = cnt + 1 end end
            ImGui.Text(string.format("%d / %d matched", cnt, #state.test_results))
            ImGui.Separator()

            for _, r in ipairs(state.test_results) do
                if not state.show_matches_only or r.matched then
                    if r.matched then
                        ImGui.TextColored(ImVec4(0, 1, 0, 1), "+ " .. r.name)
                    else
                        ImGui.TextColored(ImVec4(0.4, 0.4, 0.4, 1), "- " .. r.name)
                    end
                end
            end
        end
        ImGui.EndChild()
    end
    ImGui.End()
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function FilterGUI.run()
    state.open = true
    scan_available_filters()

    ImGui.Register('BootyFilterGUI', FilterGUI_Loop)
    helpers.success("Filter GUI started")

    while state.open do
        mq.delay(100)
    end

    helpers.info("Filter GUI closed")
end

function FilterGUI.close()
    state.open = false
end

return FilterGUI
